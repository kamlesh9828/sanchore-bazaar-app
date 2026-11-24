/**
 * SANCHORE BAZAAR API - CLOUDFLARE WORKER
 *
 * Required Cloudflare Variables:
 * FIREBASE_PROJECT_ID
 * FIREBASE_WEB_API_KEY
 *
 * Required Cloudflare Secret:
 * FIREBASE_SERVICE_ACCOUNT_JSON
 */

let cachedGoogleToken = '';
let cachedGoogleTokenExpiry = 0;

const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
  'Access-Control-Max-Age': '86400',
};

function json(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      ...CORS_HEADERS,
      'Content-Type': 'application/json; charset=utf-8',
    },
  });
}

function base64Url(bytesOrString) {
  let bytes;
  if (typeof bytesOrString === 'string') {
    bytes = new TextEncoder().encode(bytesOrString);
  } else {
    bytes = bytesOrString;
  }
  let binary = '';
  for (let i = 0; i < bytes.length; i++) {
    binary += String.fromCharCode(bytes[i]);
  }
  let encoded = btoa(binary);
  encoded = encoded.replace(/=/g, '');
  encoded = encoded.replace(/\+/g, '-');
  encoded = encoded.replace(/\//g, '_');
  return encoded;
}

function pemToBytes(pem) {
  const clean = pem.replace(
    /-----BEGIN PRIVATE KEY-----|-----END PRIVATE KEY-----|\s/g,
    '',
  );
  const binary = atob(clean);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes;
}


let cachedAdmobVerifierKeys = null;
let cachedAdmobVerifierKeysAt = 0;

function decodeBase64Url(value) {
  const normalized = String(value || '').replace(/-/g, '+').replace(/_/g, '/');
  const padded = normalized + '='.repeat((4 - normalized.length % 4) % 4);
  const binary = atob(padded);
  return Uint8Array.from(binary, (c) => c.charCodeAt(0));
}

function publicPemToBytes(pem) {
  const clean = String(pem || '').replace(/-----BEGIN PUBLIC KEY-----|-----END PUBLIC KEY-----|\s/g, '');
  const binary = atob(clean);
  return Uint8Array.from(binary, (c) => c.charCodeAt(0));
}

// WebCrypto expects the IEEE-P1363 (r || s) form; AdMob sends ASN.1 DER.
function derEcdsaToRaw(der) {
  let offset = 0;
  if (der[offset++] !== 0x30) throw new Error('Invalid SSV signature');
  let sequenceLength = der[offset++];
  if (sequenceLength & 0x80) {
    const count = sequenceLength & 0x7f;
    sequenceLength = 0;
    for (let i = 0; i < count; i++) sequenceLength = (sequenceLength << 8) | der[offset++];
  }
  if (offset + sequenceLength !== der.length || der[offset++] !== 0x02) throw new Error('Invalid SSV signature');
  const rLength = der[offset++];
  let r = der.slice(offset, offset + rLength); offset += rLength;
  if (der[offset++] !== 0x02) throw new Error('Invalid SSV signature');
  const sLength = der[offset++];
  let sigS = der.slice(offset, offset + sLength);
  while (r.length > 32 && r[0] === 0) r = r.slice(1);
  while (sigS.length > 32 && sigS[0] === 0) sigS = sigS.slice(1);
  if (r.length > 32 || sigS.length > 32) throw new Error('Invalid SSV signature');
  const raw = new Uint8Array(64);
  raw.set(r, 32 - r.length);
  raw.set(sigS, 64 - sigS.length);
  return raw;
}

async function getAdmobVerifierKey(keyId) {
  const now = Date.now();
  if (!cachedAdmobVerifierKeys || now - cachedAdmobVerifierKeysAt > 6 * 60 * 60 * 1000) {
    const response = await fetch('https://www.gstatic.com/admob/reward/verifier-keys.json');
    if (!response.ok) throw new Error('AdMob verification keys are unavailable');
    const payload = await response.json();
    cachedAdmobVerifierKeys = Array.isArray(payload.keys) ? payload.keys : [];
    cachedAdmobVerifierKeysAt = now;
  }
  return cachedAdmobVerifierKeys.find((key) => String(key.keyId) === String(keyId)) || null;
}

async function createRewardSession(request, env, uid, token) {
  await requireRole(env, uid, token, 'customer');
  const sessionId = crypto.randomUUID().replace(/-/g, '');
  const now = new Date();
  await saveDocument(env, `reward_sessions/${sessionId}`, {
    userId: uid,
    status: 'pending',
    createdAt: now,
    expiresAt: new Date(now.getTime() + 20 * 60 * 1000),
  }, token, true);
  return json({ success: true, sessionId });
}

async function processAdmobRewardSsv(request, env) {
  try {
    const url = new URL(request.url);
    const rawQuery = url.search.startsWith('?') ? url.search.slice(1) : url.search;
    // Safe endpoint check for dashboard URL verification. This never credits a reward.
    if (!rawQuery) {
      return json({ success: true, message: 'AdMob SSV endpoint is active. No reward was credited.' }, 200);
    }
    const parts = rawQuery.split('&');
    if (parts.length < 3 || !parts[parts.length - 2].startsWith('signature=') || !parts[parts.length - 1].startsWith('key_id=')) {
      return new Response('Invalid callback format', { status: 400 });
    }
    const signature = url.searchParams.get('signature');
    const keyId = url.searchParams.get('key_id');
    const signedQuery = rawQuery.slice(0, rawQuery.lastIndexOf('&signature='));
    const userId = url.searchParams.get('user_id') || '';
    const sessionId = url.searchParams.get('custom_data') || '';
    const transactionId = url.searchParams.get('transaction_id') || '';
    const adUnit = url.searchParams.get('ad_unit') || '';
    const rewardAmount = Number(url.searchParams.get('reward_amount'));
    const rewardItem = (url.searchParams.get('reward_item') || '').trim().toLowerCase();
    const expectedAdUnit = env.ADMOB_REWARDED_AD_UNIT_ID || 'ca-app-pub-6141339446909248/2536203308';
    const allowedAdUnitIds = [expectedAdUnit, expectedAdUnit.split('/').pop()];
    if (!signature || !keyId || !userId || !/^[a-f0-9]{32}$/i.test(sessionId) || !/^[a-f0-9]{16,128}$/i.test(transactionId) || !allowedAdUnitIds.includes(adUnit) || !Number.isFinite(rewardAmount) || rewardAmount !== 1 || rewardItem !== 'point') {
      return new Response('Missing or invalid reward data', { status: 400 });
    }

    const publicKey = await getAdmobVerifierKey(keyId);
    if (!publicKey?.pem) return new Response('Unknown verification key', { status: 400 });
    const cryptoKey = await crypto.subtle.importKey('spki', publicPemToBytes(publicKey.pem), { name: 'ECDSA', namedCurve: 'P-256' }, false, ['verify']);
    const valid = await crypto.subtle.verify(
      { name: 'ECDSA', hash: 'SHA-256' },
      cryptoKey,
      derEcdsaToRaw(decodeBase64Url(signature)),
      new TextEncoder().encode(signedQuery),
    );
    if (!valid) return new Response('Invalid signature', { status: 400 });

    const token = await googleAccessToken(env);
    const transactionPath = `reward_transactions/${encodeURIComponent(transactionId)}`;
    const existingTransaction = await firestoreGet(env, transactionPath, token);
    if (existingTransaction) return new Response('OK', { status: 200 });

    const sessionPath = `reward_sessions/${encodeURIComponent(sessionId)}`;
    const [session, user] = await Promise.all([
      firestoreGet(env, sessionPath, token),
      firestoreGet(env, `users/${encodeURIComponent(userId)}`, token),
    ]);
    if (!session || !user || session.data.userId !== userId || session.data.status !== 'pending') {
      return new Response('Reward session is invalid or already used', { status: 409 });
    }
    const expiresAt = Date.parse(session.data.expiresAt || '');
    if (!Number.isFinite(expiresAt) || expiresAt < Date.now()) return new Response('Reward session expired', { status: 410 });

    const now = new Date();
    const newBalance = Math.max(0, Math.floor(Number(user.data.pointsBalance) || 0)) + 1;
    const writes = [
      { update: { name: documentName(env, transactionPath), fields: encodeFields({ userId, points: 1, rupeeValue: 0.01, source: 'admob_rewarded', adUnit, createdAt: now }) }, currentDocument: { exists: false } },
      { update: { name: documentName(env, `users/${encodeURIComponent(userId)}`), fields: encodeFields({ pointsBalance: newBalance, pointsUpdatedAt: now }) }, updateMask: { fieldPaths: ['pointsBalance', 'pointsUpdatedAt'] }, currentDocument: { updateTime: user.updateTime } },
      { update: { name: documentName(env, sessionPath), fields: encodeFields({ status: 'credited', transactionId, creditedAt: now }) }, updateMask: { fieldPaths: ['status', 'transactionId', 'creditedAt'] }, currentDocument: { updateTime: session.updateTime } },
    ];
    await firestoreCommit(env, writes, token);
    return new Response('OK', { status: 200 });
  } catch (error) {
    console.error('AdMob SSV processing failed:', error);
    return new Response('Temporary verification error', { status: 500 });
  }
}

async function googleAccessToken(env) {
  const now = Math.floor(Date.now() / 1000);
  if (cachedGoogleToken && cachedGoogleTokenExpiry > now + 60) {
    return cachedGoogleToken;
  }

  let account;
  try {
    account = JSON.parse(env.FIREBASE_SERVICE_ACCOUNT_JSON || '');
  } catch (_) {
    throw new Error('FIREBASE_SERVICE_ACCOUNT_JSON secret is not valid JSON');
  }

  if (!account.client_email || !account.private_key) {
    throw new Error('Service account JSON is missing client_email/private_key');
  }

  const header = base64Url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const claims = base64Url(JSON.stringify({
    iss: account.client_email,
    scope: 'https://www.googleapis.com/auth/datastore',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  }));

  const unsigned = `${header}.${claims}`;
  const key = await crypto.subtle.importKey(
    'pkcs8',
    pemToBytes(account.private_key),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    new TextEncoder().encode(unsigned),
  );
  const assertion = `${unsigned}.${base64Url(new Uint8Array(signature))}`;

  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion,
    }),
  });

  const data = await response.json();
  if (!response.ok || !data.access_token) {
    throw new Error(`Google service authentication failed (${response.status})`);
  }
  cachedGoogleToken = data.access_token;
  cachedGoogleTokenExpiry = now + Number(data.expires_in || 3600);
  return cachedGoogleToken;
}

async function authenticate(request, env) {
  const auth = request.headers.get('Authorization') || '';
  const match = auth.match(/^Bearer\s+(.+)$/i);
  if (!match) {
    throw Object.assign(new Error('Login required.'), { status: 401 });
  }
  if (!env.FIREBASE_WEB_API_KEY) {
    throw new Error('FIREBASE_WEB_API_KEY Worker variable is missing');
  }

  const response = await fetch(
    `https://identitytoolkit.googleapis.com/v1/accounts:lookup?key=${encodeURIComponent(env.FIREBASE_WEB_API_KEY)}`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ idToken: match[1] }),
    },
  );
  const data = await response.json();
  const user = data.users && data.users[0];

  if (!response.ok || !user || !user.localId || user.disabled === true) {
    throw Object.assign(
      new Error('Login token invalid or expired. Please login again.'),
      { status: 401 },
    );
  }
  return user.localId;
}

function decodeValue(value) {
  if (!value || typeof value !== 'object') return null;
  if ('stringValue' in value) return value.stringValue;
  if ('integerValue' in value) return Number(value.integerValue);
  if ('doubleValue' in value) return Number(value.doubleValue);
  if ('booleanValue' in value) return value.booleanValue;
  if ('timestampValue' in value) return value.timestampValue;
  if ('nullValue' in value) return null;
  if ('arrayValue' in value) {
    return (value.arrayValue.values || []).map(decodeValue);
  }
  if ('mapValue' in value) {
    return decodeFields(value.mapValue.fields || {});
  }
  if ('geoPointValue' in value) return value.geoPointValue;
  return null;
}

function decodeFields(fields) {
  const result = {};
  for (const [key, value] of Object.entries(fields || {})) {
    result[key] = decodeValue(value);
  }
  return result;
}

function encodeValue(value) {
  if (value === null || value === undefined) return { nullValue: null };
  if (typeof value === 'boolean') return { booleanValue: value };
  if (typeof value === 'string') return { stringValue: value };
  if (typeof value === 'number') {
    return Number.isInteger(value)
      ? { integerValue: String(value) }
      : { doubleValue: value };
  }
  if (value instanceof Date) return { timestampValue: value.toISOString() };
  if (Array.isArray(value)) {
    return { arrayValue: { values: value.map(encodeValue) } };
  }
  if (typeof value === 'object') {
    return { mapValue: { fields: encodeFields(value) } };
  }
  return { stringValue: String(value) };
}

function encodeFields(data) {
  const fields = {};
  for (const [key, value] of Object.entries(data)) {
    fields[key] = encodeValue(value);
  }
  return fields;
}

function documentUrl(env, path) {
  const project = encodeURIComponent(env.FIREBASE_PROJECT_ID || '');
  if (!project) throw new Error('FIREBASE_PROJECT_ID Worker variable is missing');
  return `https://firestore.googleapis.com/v1/projects/${project}/databases/(default)/documents/${path}`;
}

function documentName(env, path) {
  const project = env.FIREBASE_PROJECT_ID || '';
  if (!project) throw new Error('FIREBASE_PROJECT_ID Worker variable is missing');
  return `projects/${project}/databases/(default)/documents/${path}`;
}

async function firestoreGet(env, path, token) {
  const response = await fetch(documentUrl(env, path), {
    headers: { Authorization: `Bearer ${token}` },
  });
  if (response.status === 404) return null;
  const data = await response.json();
  if (!response.ok) {
    throw new Error(`Firestore read failed (${response.status}): ${data.error?.message || 'Unknown error'}`);
  }
  return {
    data: decodeFields(data.fields || {}),
    updateTime: data.updateTime,
    name: data.name,
  };
}

async function firestoreCommit(env, writes, token) {
  const project = encodeURIComponent(env.FIREBASE_PROJECT_ID || '');
  if (!project) throw new Error('FIREBASE_PROJECT_ID Worker variable is missing');

  const response = await fetch(
    `https://firestore.googleapis.com/v1/projects/${project}/databases/(default)/documents:commit`,
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${token}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ writes }),
    },
  );
  const data = await response.json();

  if (!response.ok) {
    const conflict =
      response.status === 409 ||
      /FAILED_PRECONDITION|ABORTED/i.test(data.error?.status || '');
    throw Object.assign(
      new Error(
        conflict
          ? 'Stock or data changed while placing the order. Please refresh cart and try again.'
          : `Firestore save failed (${response.status}): ${data.error?.message || 'Unknown error'}`,
      ),
      { status: conflict ? 409 : 502 },
    );
  }
  return data;
}

function roundMoney(value) {
  return Math.round((value + Number.EPSILON) * 100) / 100;
}

async function requireRole(env, uid, token, role) {
  const user = await firestoreGet(env, `users/${encodeURIComponent(uid)}`, token);
  if (
    !user ||
    user.data.role !== role ||
    user.data.approved !== true ||
    user.data.active === false
  ) {
    throw Object.assign(
      new Error(`${role === 'admin' ? 'Admin' : 'Required'} permission required.`),
      { status: 403 },
    );
  }
  return user.data;
}


async function adminSavePaymentSettings(request, env, uid, token) {
  await requireRole(env, uid, token, 'admin');
  const body = await request.json();
  if (typeof body.codEnabled !== 'boolean') {
    throw Object.assign(new Error('codEnabled boolean hona chahiye.'), { status: 400 });
  }
  const paymentSettings = await firestoreGet(env, 'settings/payment', token);
  await saveDocument(env, 'settings/payment', {
    codEnabled: body.codEnabled,
    updatedBy: uid,
    updatedAt: new Date(),
  }, token, !paymentSettings);
  return json({ success: true, codEnabled: body.codEnabled });
}

async function saveFeeSettings(request, env, uid, token) {
  await requireRole(env, uid, token, 'admin');
  const d = await request.json();
  const values = [
    Number(d.commissionPercent),
    Number(d.deliveryPayout),
    Number(d.customerDeliveryCharge),
    Number(d.platformFee),
  ];
  const payer = d.deliveryPayer || 'company';

  if (
    !values.every(Number.isFinite) ||
    values[0] < 0 || values[0] > 100 ||
    values.slice(1).some(v => v < 0) ||
    !['company', 'customer', 'shopkeeper', 'split'].includes(payer)
  ) {
    throw Object.assign(new Error('Invalid fee settings.'), { status: 400 });
  }

  const current = await firestoreGet(env, 'settings/fees', token);
  const feeData = {
    commissionPercent: values[0],
    deliveryPayout: values[1],
    customerDeliveryCharge: values[2],
    platformFee: values[3],
    deliveryPayer: payer,
    updatedBy: uid,
    updatedAt: new Date(),
  };
  const write = {
    update: {
      name: documentName(env, 'settings/fees'),
      fields: encodeFields(feeData),
    },
    updateMask: { fieldPaths: Object.keys(feeData) },
  };
  if (!current) write.currentDocument = { exists: false };
  else write.currentDocument = { updateTime: current.updateTime };

  await firestoreCommit(env, [write], token);
  return json({ success: true, message: 'Fee settings saved.' });
}

function distanceKm(lat1, lon1, lat2, lon2) {
  const rad = v => v * Math.PI / 180;
  const dLat = rad(lat2 - lat1), dLon = rad(lon2 - lon1);
  const a = Math.sin(dLat / 2) ** 2 + Math.cos(rad(lat1)) * Math.cos(rad(lat2)) * Math.sin(dLon / 2) ** 2;
  return 6371 * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

async function assertServiceArea(env, token, latitude, longitude, pinCode = '') {
  const areas = await firestoreList(env, 'service_areas', token, 1000);
  const configuredPinAreas = areas.filter(x => /^\d{6}$/.test(String(x.data.pinCode || '')));
  const pinAreas = configuredPinAreas.filter(x => x.data.active === true);
  const pin = String(pinCode || '').trim();
  if (configuredPinAreas.length) {
    if (!/^\d{6}$/.test(pin)) throw Object.assign(new Error('Delivery address ka 6 digit PIN code bharein.'), { status: 400 });
    const match = pinAreas.some(x => String(x.data.pinCode) === pin);
    if (!match) throw Object.assign(new Error('Maaf kijiye, is PIN code par abhi delivery uplabdh nahi hai.'), { status: 403 });
    return;
  }
  // Backward compatibility: existing radius-based areas continue to work until PIN codes are configured.
  if (!Number.isFinite(latitude) || latitude < -90 || latitude > 90 ||
      !Number.isFinite(longitude) || longitude < -180 || longitude > 180) {
    throw Object.assign(new Error('Admin se delivery PIN code set karwayein ya GPS location select karein.'), { status: 400 });
  }
  const active = areas.filter(x => x.data.active === true);
  if (!active.length) throw Object.assign(new Error('Abhi service area Admin ne set nahi kiya hai.'), { status: 403 });
  const inside = active.some(x => {
    const c = x.data.center || {};
    const lat = Number(c.latitude), lon = Number(c.longitude), radius = Number(x.data.radiusKm);
    return Number.isFinite(lat) && Number.isFinite(lon) && Number.isFinite(radius) && radius > 0 && distanceKm(latitude, longitude, lat, lon) <= radius;
  });
  if (!inside) throw Object.assign(new Error('Aapka address abhi Sanchore Bazaar delivery area mein nahi aata.'), { status: 403 });
}

function paytmConfig(env) {
  const mid = String(env.PAYTM_MID || '').trim();
  const key = String(env.PAYTM_MERCHANT_KEY || '').trim();
  const mode = String(env.PAYTM_ENV || 'STAGING').toUpperCase();
  if (!mid || !key || key.length !== 16 || !['STAGING', 'PRODUCTION'].includes(mode)) {
    throw Object.assign(new Error('Paytm Worker secrets/variables configure nahi hain.'), { status: 503 });
  }
  return { mid, key, mode, website: String(env.PAYTM_WEBSITE_NAME || (mode === 'PRODUCTION' ? 'DEFAULT' : 'WEBSTAGING')), host: mode === 'PRODUCTION' ? 'https://secure.paytmpayments.com' : 'https://securestage.paytmpayments.com' };
}

function bytesToBase64(bytes) {
  let binary = '';
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary);
}

async function paytmGenerateChecksum(bodyString, merchantKey) {
  const saltBytes = crypto.getRandomValues(new Uint8Array(3));
  const salt = bytesToBase64(saltBytes);
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(`${bodyString}|${salt}`));
  const hash = Array.from(new Uint8Array(digest)).map(x => x.toString(16).padStart(2, '0')).join('') + salt;
  const key = await crypto.subtle.importKey('raw', new TextEncoder().encode(merchantKey), { name: 'AES-CBC' }, false, ['encrypt']);
  const iv = new TextEncoder().encode('@@@@&&&&####$$$$');
  const encrypted = await crypto.subtle.encrypt({ name: 'AES-CBC', iv }, key, new TextEncoder().encode(hash));
  return bytesToBase64(new Uint8Array(encrypted));
}

async function paytmVerifyChecksum(bodyString, merchantKey, checksum) {
  try {
    const binary = atob(checksum);
    const encrypted = Uint8Array.from(binary, c => c.charCodeAt(0));
    const key = await crypto.subtle.importKey('raw', new TextEncoder().encode(merchantKey), { name: 'AES-CBC' }, false, ['decrypt']);
    const iv = new TextEncoder().encode('@@@@&&&&####$$$$');
    const decrypted = await crypto.subtle.decrypt({ name: 'AES-CBC', iv }, key, encrypted);
    const actual = new TextDecoder().decode(decrypted);
    const salt = actual.slice(-4);
    const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(`${bodyString}|${salt}`));
    const expected = Array.from(new Uint8Array(digest)).map(x => x.toString(16).padStart(2, '0')).join('') + salt;
    return actual === expected;
  } catch (_) { return false; }
}


const DEFAULT_SHOPKEEPER_PRO_PLANS = {
  monthly: { title: 'Pro मासिक', amount: 299, durationDays: 30 },
  yearly: { title: 'Pro वार्षिक', amount: 2999, durationDays: 365 },
};

async function shopkeeperProInfo(request, env, uid, token) {
  await requireRole(env, uid, token, 'shopkeeper');
  const body = await request.json().catch(() => ({}));
  const shopId = String(body.shopId || '');
  const shop = await firestoreGet(env, `shops/${encodeURIComponent(shopId)}`, token);
  if (!shop || shop.data.ownerId !== uid) throw Object.assign(new Error('दुकान का अधिकार सत्यापित नहीं हुआ।'), { status: 403 });
  const saved = await firestoreGet(env, 'settings/shopkeeper_pro', token);
  const prices = saved?.data?.plans || {};
  const plans = Object.fromEntries(Object.entries(DEFAULT_SHOPKEEPER_PRO_PLANS).map(([id, plan]) => [id, {
    ...plan,
    amount: roundMoney(Number(prices[id]?.amount ?? plan.amount)),
    benefits: id === 'monthly'
      ? ['दुकान पर Pro बैज', 'ग्राहक की दुकान सूची में प्राथमिकता', 'सदस्यता की अवधि और नवीनीकरण नियंत्रण']
      : ['दुकान पर Pro बैज', 'ग्राहक की दुकान सूची में प्राथमिकता', 'सदस्यता की अवधि और नवीनीकरण नियंत्रण', '12 महीने की सदस्यता']
  }]));
  const until = shop.data.proUntil || null;
  const active = shop.data.proStatus === 'active' && until && Date.parse(until) > Date.now();
  return json({ success: true, shopId, plans, subscription: {
    status: active ? 'active' : (shop.data.proStatus === 'active' ? 'expired' : (shop.data.proStatus || 'inactive')),
    planId: shop.data.proPlan || '', until,
    remainingDays: active ? Math.max(0, Math.ceil((Date.parse(until) - Date.now()) / 86400000)) : 0,
  }});
}

async function shopkeeperCreateProPayment(request, env, uid, token) {
  await requireRole(env, uid, token, 'shopkeeper');
  const body = await request.json();
  const shopId = String(body.shopId || '');
  const planId = String(body.planId || '');
  const shop = await firestoreGet(env, `shops/${encodeURIComponent(shopId)}`, token);
  if (!shop || shop.data.ownerId !== uid || shop.data.approved !== true || shop.data.active !== true) {
    throw Object.assign(new Error('सदस्यता लेने के लिए आपकी दुकान का स्वीकृत और सक्रिय होना जरूरी है।'), { status: 403 });
  }
  if (!Object.prototype.hasOwnProperty.call(DEFAULT_SHOPKEEPER_PRO_PLANS, planId)) throw Object.assign(new Error('सदस्यता योजना मान्य नहीं है।'), { status: 400 });
  const saved = await firestoreGet(env, 'settings/shopkeeper_pro', token);
  const defaultPlan = DEFAULT_SHOPKEEPER_PRO_PLANS[planId];
  const amount = roundMoney(Number(saved?.data?.plans?.[planId]?.amount ?? defaultPlan.amount));
  if (!Number.isFinite(amount) || amount < 1 || amount > 100000) throw Object.assign(new Error('सदस्यता की कीमत सही नहीं है।'), { status: 400 });
  const sessionId = `SBPRO${crypto.randomUUID().replace(/-/g, '').slice(0, 24)}`;
  const now = new Date();
  const subscriptionPath = `shopkeeper_subscriptions/${sessionId}`;
  await saveDocument(env, subscriptionPath, {
    ownerId: uid, shopId, planId, planTitle: defaultPlan.title, amount,
    status: 'pending', paymentStatus: 'pending', createdAt: now,
  }, token, true);
  await saveDocument(env, `payment_sessions/${sessionId}`, {
    customerId: uid, paymentType: 'shopkeeper_pro', shopId, subscriptionId: sessionId,
    planId, amount, paymentStatus: 'pending', gateway: 'paytm', createdAt: now, updatedAt: now,
  }, token, true);
  return json({ success: true, sessionId, amount });
}

async function adminShopkeeperProSettings(request, env, uid, token) {
  await requireRole(env, uid, token, 'admin');
  const saved = await firestoreGet(env, 'settings/shopkeeper_pro', token);
  return json({ success: true, plans: {
    monthly: { amount: roundMoney(Number(saved?.data?.plans?.monthly?.amount ?? 299)) },
    yearly: { amount: roundMoney(Number(saved?.data?.plans?.yearly?.amount ?? 2999)) },
  }});
}

async function adminSaveShopkeeperProPrices(request, env, uid, token) {
  await requireRole(env, uid, token, 'admin');
  const body = await request.json();
  const monthly = roundMoney(Number(body.monthly));
  const yearly = roundMoney(Number(body.yearly));
  if (![monthly, yearly].every(v => Number.isFinite(v) && v >= 1 && v <= 100000) || yearly < monthly) {
    throw Object.assign(new Error('मासिक और वार्षिक कीमत सही भरें। वार्षिक कीमत मासिक से कम नहीं हो सकती।'), { status: 400 });
  }
  await saveDocument(env, 'settings/shopkeeper_pro', {
    plans: { monthly: { amount: monthly }, yearly: { amount: yearly } },
    updatedAt: new Date(), updatedBy: uid,
  }, token, true).catch(async () => {
    const old = await firestoreGet(env, 'settings/shopkeeper_pro', token);
    if (!old) throw new Error('सदस्यता कीमत सेव नहीं हो सकी।');
    await firestoreCommit(env, [{ update: { name: documentName(env, 'settings/shopkeeper_pro'), fields: encodeFields({ plans: { monthly: { amount: monthly }, yearly: { amount: yearly } }, updatedAt: new Date(), updatedBy: uid }) }, updateMask: { fieldPaths: ['plans','updatedAt','updatedBy'] }, currentDocument: { updateTime: old.updateTime } }], token);
  });
  return json({ success: true, monthly, yearly });
}

async function adminSetShopkeeperProStatus(request, env, uid, token) {
  await requireRole(env, uid, token, 'admin');
  const body = await request.json();
  const shopId = String(body.shopId || '');
  const action = String(body.action || '');
  if (!['suspend', 'restore'].includes(action)) throw Object.assign(new Error('कार्रवाई मान्य नहीं है।'), { status: 400 });
  const shop = await firestoreGet(env, `shops/${encodeURIComponent(shopId)}`, token);
  if (!shop) throw Object.assign(new Error('दुकान नहीं मिली।'), { status: 404 });
  const active = action === 'restore' && shop.data.proUntil && Date.parse(shop.data.proUntil) > Date.now();
  await saveDocument(env, `shops/${encodeURIComponent(shopId)}`, {
    proStatus: active ? 'active' : (action === 'suspend' ? 'suspended' : 'expired'),
    proAdminUpdatedAt: new Date(), proAdminUpdatedBy: uid,
  }, token);
  return json({ success: true, status: active ? 'active' : (action === 'suspend' ? 'suspended' : 'expired') });
}

async function adminGrantShopkeeperPro(request, env, uid, token) {
  await requireRole(env, uid, token, 'admin');
  const body = await request.json();
  const shopId = String(body.shopId || '').trim();
  const durationDays = Number(body.durationDays);
  if (!shopId || !Number.isInteger(durationDays) || ![30, 90, 180, 365].includes(durationDays)) {
    throw Object.assign(new Error('दुकान और सदस्यता की अवधि सही चुनें।'), { status: 400 });
  }
  const shop = await firestoreGet(env, `shops/${encodeURIComponent(shopId)}`, token);
  if (!shop || shop.data.approved !== true || shop.data.active !== true) {
    throw Object.assign(new Error('केवल स्वीकृत और सक्रिय दुकान को Pro दिया जा सकता है।'), { status: 409 });
  }
  const now = new Date();
  const currentExpiry = Date.parse(shop.data.proUntil || '');
  const base = shop.data.proStatus === 'active' && Number.isFinite(currentExpiry) && currentExpiry > now.getTime()
    ? new Date(currentExpiry) : now;
  const expiry = new Date(base.getTime() + durationDays * 86400000);
  const planId = `admin_${durationDays}d`;
  await saveDocument(env, `shops/${encodeURIComponent(shopId)}`, {
    proStatus: 'active', proPlan: planId, proStartedAt: shop.data.proStartedAt || now,
    proUntil: expiry, proGrantedByAdmin: true, proAdminUpdatedAt: now, proAdminUpdatedBy: uid,
  }, token);
  const recordId = `SBADMINPRO${crypto.randomUUID().replace(/-/g, '').slice(0, 20)}`;
  await saveDocument(env, `shopkeeper_subscriptions/${recordId}`, {
    ownerId: shop.data.ownerId || '', shopId, planId, planTitle: `Admin द्वारा Pro (${durationDays} दिन)`,
    amount: 0, status: 'active', paymentStatus: 'admin_granted', grantedBy: uid,
    durationDays, createdAt: now, until: expiry,
  }, token, true);
  return json({ success: true, shopId, durationDays, until: expiry.toISOString() });
}

async function paytmInitiate(request, env, uid, token) {
  const { sessionId } = await request.json();
  const id = String(sessionId || '');
  const session = await firestoreGet(env, `payment_sessions/${encodeURIComponent(id)}`, token);
  const user = await firestoreGet(env, `users/${encodeURIComponent(uid)}`, token);
  const allowedRole = user && user.data.approved === true && user.data.active !== false && (user.data.role === 'customer' || user.data.role === 'shopkeeper');
  if (!allowedRole || !session || session.data.customerId !== uid || session.data.paymentStatus !== 'pending') {
    throw Object.assign(new Error('Payment session nahi mila ya expire ho gaya.'), { status: 404 });
  }
  const cfg = paytmConfig(env);
  const body = {
    requestType: 'Payment', mid: cfg.mid, websiteName: cfg.website,
    orderId: id,
    txnAmount: { value: Number(session.data.amount).toFixed(2), currency: 'INR' },
    userInfo: { custId: uid },
  };
  const bodyString = JSON.stringify(body);
  const signature = await paytmGenerateChecksum(bodyString, cfg.key);
  let response, result;
  try {
    response = await fetch(`${cfg.host}/theia/api/v1/initiateTransaction?mid=${encodeURIComponent(cfg.mid)}&orderId=${encodeURIComponent(id)}`, {
      method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ body, head: { signature } }),
    });
    result = await response.json();
  } catch (error) {
    await failPaytmSessionAndRestoreStock(env, id, session, token, 'initiate_network_error');
    throw Object.assign(new Error(session.data.paymentType === 'shopkeeper_pro' ? 'Paytm भुगतान शुरू नहीं हो सका। कृपया दोबारा प्रयास करें।' : 'Paytm se payment session nahi ban paya. Stock release kar diya gaya hai; dobara order karein.'), { status: 502 });
  }
  if (!response.ok || result.body?.resultInfo?.resultStatus !== 'S' || !result.body?.txnToken) {
    await failPaytmSessionAndRestoreStock(env, id, session, token, 'initiate_rejected');
    throw Object.assign(new Error(result.body?.resultInfo?.resultMsg || (session.data.paymentType === 'shopkeeper_pro' ? 'Paytm भुगतान शुरू नहीं हुआ। कृपया दोबारा प्रयास करें।' : 'Paytm transaction start nahi hua. Stock release kar diya gaya hai; dobara order karein.')), { status: 502 });
  }
  const checkoutUrl = `${env.WORKER_PUBLIC_URL || 'https://sanchore-bazaar-api.kamlesh9828-kp.workers.dev'}/paytm/checkout?orderId=${encodeURIComponent(id)}&token=${encodeURIComponent(result.body.txnToken)}&amount=${encodeURIComponent(body.txnAmount.value)}`;
  return json({ success: true, checkoutUrl, orderId: id, amount: body.txnAmount.value });
}

async function failPaytmSessionAndRestoreStock(env, sessionId, session, token, reason = 'payment_failed') {
  if (!session || session.data.paymentStatus !== 'pending') return false;
  const now = new Date();
  const writes = [];
  const productQuantities = new Map();
  for (const orderId of (Array.isArray(session.data.orderIds) ? session.data.orderIds : [])) {
    const order = await firestoreGet(env, `orders/${encodeURIComponent(orderId)}`, token);
    if (!order || order.data.paymentSessionId !== sessionId || order.data.paymentStatus === 'paid' || order.data.status !== 'pending_payment') continue;
    writes.push({
      update: { name: documentName(env, `orders/${encodeURIComponent(orderId)}`), fields: encodeFields({ status: 'payment_failed', paymentStatus: 'failed', paymentFailureReason: reason, updatedAt: now }) },
      updateMask: { fieldPaths: ['status','paymentStatus','paymentFailureReason','updatedAt'] },
      currentDocument: { updateTime: order.updateTime },
    });
    for (const item of (Array.isArray(order.data.items) ? order.data.items : [])) {
      const productId = String(item.productId || ''), quantity = Number(item.quantity);
      if (!productId || !Number.isInteger(quantity) || quantity < 1) throw Object.assign(new Error('Payment failed, but stock data is invalid. Admin reconciliation required.'), { status: 409 });
      productQuantities.set(productId, (productQuantities.get(productId) || 0) + quantity);
    }
  }
  for (const [productId, quantity] of productQuantities) {
    const product = await firestoreGet(env, `products/${encodeURIComponent(productId)}`, token);
    if (!product) throw Object.assign(new Error(`Payment failed, but product ${productId} is missing. Admin reconciliation required.`), { status: 409 });
    const stock = Number(product.data.stock || 0);
    if (!Number.isInteger(stock) || stock < 0) throw Object.assign(new Error('Product stock is invalid; Admin reconciliation required.'), { status: 409 });
    writes.push({
      update: { name: documentName(env, `products/${encodeURIComponent(productId)}`), fields: encodeFields({ stock: stock + quantity, active: true, updatedAt: now }) },
      updateMask: { fieldPaths: ['stock','active','updatedAt'] },
      currentDocument: { updateTime: product.updateTime },
    });
  }
  writes.push({
    update: { name: documentName(env, `payment_sessions/${encodeURIComponent(sessionId)}`), fields: encodeFields({ paymentStatus: 'failed', failureReason: reason, updatedAt: now }) },
    updateMask: { fieldPaths: ['paymentStatus','failureReason','updatedAt'] },
    currentDocument: { updateTime: session.updateTime },
  });
  if (session.data.paymentType === 'shopkeeper_pro' && session.data.subscriptionId) {
    const subscription = await firestoreGet(env, `shopkeeper_subscriptions/${encodeURIComponent(session.data.subscriptionId)}`, token);
    if (subscription && subscription.data.status === 'pending') {
      writes.push({ update: { name: documentName(env, `shopkeeper_subscriptions/${encodeURIComponent(session.data.subscriptionId)}`), fields: encodeFields({ status: 'failed', paymentStatus: 'failed', failureReason: reason, updatedAt: now }) }, updateMask: { fieldPaths: ['status','paymentStatus','failureReason','updatedAt'] }, currentDocument: { updateTime: subscription.updateTime } });
    }
  }
  if (writes.length > 500) throw Object.assign(new Error('Too many records to safely restore stock.'), { status: 400 });
  if (writes.length) await firestoreCommit(env, writes, token);
  return true;
}

async function paytmVerify(request, env, uid, token) {
  const { orderId } = await request.json();
  const id = String(orderId || '');
  const session = await firestoreGet(env, `payment_sessions/${encodeURIComponent(id)}`, token);
  if (!session || session.data.customerId !== uid) {
    throw Object.assign(new Error('Payment session not found or access denied.'), { status: 404 });
  }
  const sessionUser = await firestoreGet(env, `users/${encodeURIComponent(uid)}`, token);
  if (!sessionUser || sessionUser.data.approved !== true || sessionUser.data.active === false || !['customer', 'shopkeeper'].includes(sessionUser.data.role)) {
    throw Object.assign(new Error('सक्रिय अकाउंट से लॉगिन करें।'), { status: 403 });
  }
  if (session.data.paymentStatus === 'paid') return json({ success: true, paid: true });
  if (session.data.paymentStatus !== 'pending') return json({ success: true, paid: false, status: 'EXPIRED' });
  const cfg = paytmConfig(env);
  const body = { mid: cfg.mid, orderId: id };
  const signature = await paytmGenerateChecksum(JSON.stringify(body), cfg.key);
  const response = await fetch(`${cfg.host}/v3/order/status`, {
    method: 'POST', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ body, head: { signature } }),
  });
  const result = await response.json();
  const responseBody = result.body || {};
  if (!response.ok || !result.head?.signature ||
      !await paytmVerifyChecksum(JSON.stringify(responseBody), cfg.key, result.head.signature)) {
    throw Object.assign(new Error('Paytm status response checksum verify nahi hua.'), { status: 502 });
  }
  const amountMatches = Number(responseBody.txnAmount).toFixed(2) === Number(session.data.amount).toFixed(2);
  const gatewayStatus = String(responseBody.resultInfo?.resultStatus || 'PENDING').toUpperCase();
  const paid = gatewayStatus === 'TXN_SUCCESS' &&
    responseBody.orderId === id && responseBody.mid === cfg.mid && amountMatches;
  if (!paid) {
    if (['TXN_FAILURE', 'CANCELLED', 'CANCELED', 'NO_RECORD'].includes(gatewayStatus)) {
      await failPaytmSessionAndRestoreStock(env, id, session, token, gatewayStatus.toLowerCase());
    }
    return json({ success: true, paid: false, status: gatewayStatus });
  }
  const now = new Date();
  const writes = [{
    update: { name: documentName(env, `payment_sessions/${encodeURIComponent(id)}`), fields: encodeFields({ paymentStatus: 'paid', transactionId: String(responseBody.txnId || ''), paidAt: now, updatedAt: now }) },
    updateMask: { fieldPaths: ['paymentStatus','transactionId','paidAt','updatedAt'] },
    currentDocument: { updateTime: session.updateTime },
  }];
  for (const orderId of (Array.isArray(session.data.orderIds) ? session.data.orderIds : [])) {
    const order = await firestoreGet(env, `orders/${encodeURIComponent(orderId)}`, token);
    if (!order || order.data.paymentSessionId !== id || order.data.paymentStatus === 'paid') continue;
    writes.push({
      update: { name: documentName(env, `orders/${encodeURIComponent(orderId)}`), fields: encodeFields({ paymentStatus: 'paid', status: 'placed', transactionId: String(responseBody.txnId || ''), paidAt: now, updatedAt: now }) },
      updateMask: { fieldPaths: ['paymentStatus','status','transactionId','paidAt','updatedAt'] },
      currentDocument: { updateTime: order.updateTime },
    });
  }
  if (session.data.paymentType === 'advertisement' && session.data.campaignId) {
    const campaignPath = `ad_campaigns/${encodeURIComponent(session.data.campaignId)}`;
    const campaign = await firestoreGet(env, campaignPath, token);
    if (!campaign || campaign.data.ownerId !== uid || campaign.data.status !== 'awaiting_payment' || campaign.data.paymentStatus !== 'pending' || Number(campaign.data.amount).toFixed(2) !== Number(session.data.amount).toFixed(2)) {
      throw Object.assign(new Error('भुगतान मिल गया, लेकिन विज्ञापन की स्थिति बदल चुकी है। एडमिन से संपर्क करें।'), { status: 409 });
    }
    writes.push({
      update: { name: documentName(env, campaignPath), fields: encodeFields({ paymentStatus: 'paid', status: 'active', transactionId: String(responseBody.txnId || ''), paidAt: now, updatedAt: now }) },
      updateMask: { fieldPaths: ['paymentStatus','status','transactionId','paidAt','updatedAt'] },
      currentDocument: { updateTime: campaign.updateTime },
    });
  }
  if (session.data.paymentType === 'shopkeeper_pro' && session.data.shopId && session.data.subscriptionId) {
    const shopPath = `shops/${encodeURIComponent(session.data.shopId)}`;
    const subscriptionPath = `shopkeeper_subscriptions/${encodeURIComponent(session.data.subscriptionId)}`;
    const [shop, subscription] = await Promise.all([
      firestoreGet(env, shopPath, token), firestoreGet(env, subscriptionPath, token),
    ]);
    if (!shop || shop.data.ownerId !== uid || !shop.data.approved || !shop.data.active ||
        !subscription || subscription.data.ownerId !== uid || subscription.data.status !== 'pending' ||
        Number(subscription.data.amount).toFixed(2) !== Number(session.data.amount).toFixed(2)) {
      throw Object.assign(new Error('भुगतान मिल गया, लेकिन सदस्यता की जानकारी सत्यापित नहीं हुई। Admin से संपर्क करें।'), { status: 409 });
    }
    const now = new Date();
    const currentExpiry = Date.parse(shop.data.proUntil || '');
    const start = Number.isFinite(currentExpiry) && currentExpiry > now.getTime() ? new Date(currentExpiry) : now;
    const durationDays = session.data.planId === 'yearly' ? 365 : (session.data.planId === 'monthly' ? 30 : 0);
    if (!durationDays) throw Object.assign(new Error('सदस्यता योजना मान्य नहीं है।'), { status: 409 });
    const expiry = new Date(start.getTime() + durationDays * 24 * 60 * 60 * 1000);
    writes.push({
      update: { name: documentName(env, shopPath), fields: encodeFields({ proStatus: 'active', proPlan: session.data.planId, proStartedAt: now, proUntil: expiry, proPaymentId: String(responseBody.txnId || ''), proUpdatedAt: now }) },
      updateMask: { fieldPaths: ['proStatus','proPlan','proStartedAt','proUntil','proPaymentId','proUpdatedAt'] },
      currentDocument: { updateTime: shop.updateTime },
    });
    writes.push({
      update: { name: documentName(env, subscriptionPath), fields: encodeFields({ status: 'active', paymentStatus: 'paid', transactionId: String(responseBody.txnId || ''), paidAt: now, startsAt: start, expiresAt: expiry }) },
      updateMask: { fieldPaths: ['status','paymentStatus','transactionId','paidAt','startsAt','expiresAt'] },
      currentDocument: { updateTime: subscription.updateTime },
    });
  }
  await firestoreCommit(env, writes, token);
  return json({ success: true, paid: true, transactionId: String(responseBody.txnId || '') });
}

function paytmCheckoutPage(request, env) {
  let cfg;
  try { cfg = paytmConfig(env); } catch (e) { return new Response('Paytm configuration missing.', { status: 503 }); }
  const url = new URL(request.url);
  const orderId = url.searchParams.get('orderId') || '';
  const txnToken = url.searchParams.get('token') || '';
  const amount = url.searchParams.get('amount') || '';
  if (!/^[A-Za-z0-9_-]{8,50}$/.test(orderId) || !txnToken || !/^\d+\.\d{2}$/.test(amount)) return new Response('Invalid checkout request.', { status: 400 });
  const safe = value => JSON.stringify(value).replace(/</g, '\\u003c');
  const html = `<!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1"><title>Sanchore Bazaar सुरक्षित भुगतान</title><style>body{font-family:Arial;background:#f3f8f5;margin:0;padding:20px;color:#173b2d}.card{max-width:520px;margin:30px auto;background:white;padding:22px;border-radius:18px;box-shadow:0 8px 28px #0001;text-align:center}button{background:#087e58;color:white;border:0;border-radius:12px;padding:14px 22px;font-size:16px}</style><script src="${cfg.host}/merchantpgpui/checkoutjs/merchants/${encodeURIComponent(cfg.mid)}.js" crossorigin="anonymous"></script></head><body><div class="card"><h2>Sanchore Bazaar</h2><p>सुरक्षित ऑनलाइन भुगतान</p><h1>₹${amount}</h1><p>नीचे उपलब्ध विकल्पों में से भुगतान का तरीका चुनें</p><p>भुगतान के लिए Paytm पर उपलब्ध UPI ऐप, QR कोड, डेबिट/क्रेडिट कार्ड या नेट बैंकिंग में से विकल्प चुनें।</p><p id="msg">सुरक्षित भुगतान विकल्प लोड हो रहे हैं…</p><button id="retry" style="display:none" onclick="startPayment()">दोबारा प्रयास करें</button></div><script>
const orderId=${safe(orderId)}, token=${safe(txnToken)}, amount=${safe(amount)};
function notifyApp(value){try{if(window.PaytmResult&&window.PaytmResult.postMessage)window.PaytmResult.postMessage(value)}catch(e){}}
function verify(){document.getElementById('msg').innerText='भुगतान की स्थिति सुरक्षित सर्वर पर जाँची जा रही है…';notifyApp('VERIFY')}
function startPayment(){if(!window.Paytm||!window.Paytm.CheckoutJS){document.getElementById('msg').innerText='ऑनलाइन भुगतान विकल्प लोड नहीं हो सके। इंटरनेट जाँचकर दोबारा प्रयास करें।';document.getElementById('retry').style.display='inline-block';return}const config={root:'',flow:'DEFAULT',data:{orderId,token,tokenType:'TXN_TOKEN',amount},merchant:{redirect:false},handler:{transactionStatus:function(){verify()},notifyMerchant:function(eventName,data){if(eventName==='APP_CLOSED'){document.getElementById('msg').innerText='भुगतान विंडो बंद हुई है। भुगतान की स्थिति जाँची जा रही है।';verify()}}}};window.Paytm.CheckoutJS.onLoad(function(){window.Paytm.CheckoutJS.init(config).then(function(){window.Paytm.CheckoutJS.invoke()}).catch(function(){document.getElementById('msg').innerText='ऑनलाइन भुगतान शुरू नहीं हो सका।'})})}
window.addEventListener('load',startPayment);
</script></body></html>`;
  return new Response(html, { headers: { 'Content-Type': 'text/html; charset=utf-8', 'Cache-Control': 'no-store', ...CORS_HEADERS } });
}

async function createOrder(request, env, uid, token) {
  await requireRole(env, uid, token, 'customer');
  const body = await request.json();

  const paymentMethod = String(body.paymentMethod || 'cod');
  if (!['cod', 'paytm'].includes(paymentMethod) || typeof body.address !== 'string' || !body.address.trim()) {
    throw Object.assign(new Error('Valid address and payment method are required.'), { status: 400 });
  }
  const latitude = body.latitude == null ? NaN : Number(body.latitude);
  const longitude = body.longitude == null ? NaN : Number(body.longitude);
  const pinCode = String(body.pinCode || '').trim();
  await assertServiceArea(env, token, latitude, longitude, pinCode);

  const groups = Array.isArray(body.groups)
    ? body.groups
    : [{ shopId: body.shopId, items: body.items }];

  if (!groups.length || groups.length > 20) {
    throw Object.assign(new Error('Cart shop groups are invalid.'), { status: 400 });
  }

  let totalItems = 0;
  const seen = new Set();
  for (const group of groups) {
    if (!group || typeof group.shopId !== 'string' || !group.shopId ||
        !Array.isArray(group.items) || !group.items.length) {
      throw Object.assign(new Error('Each shop must have valid cart items.'), { status: 400 });
    }
    totalItems += group.items.length;
    for (const item of group.items) {
      const id = String(item.productId || '');
      const quantity = Number(item.quantity);
      if (!id || !Number.isInteger(quantity) || quantity < 1 ||
          quantity > 99 || seen.has(id)) {
        throw Object.assign(new Error('Invalid or duplicate cart item.'), { status: 400 });
      }
      seen.add(id);
    }
  }

  if (totalItems > 100) {
    throw Object.assign(new Error('Cart contains too many items.'), { status: 400 });
  }

  const [paymentSettings, customerProfile] = await Promise.all([
    firestoreGet(env, 'settings/payment', token),
    firestoreGet(env, `users/${encodeURIComponent(uid)}`, token),
  ]);
  const codEnabled = paymentSettings?.data?.codEnabled !== false;
  if (paymentMethod === 'cod' && (!codEnabled || customerProfile?.data?.codEnabled === false || customerProfile?.data?.codDisabled === true)) {
    throw Object.assign(new Error('आपके खाते पर Cash on Delivery बंद है। कृपया Online Payment चुनें।'), { status: 409 });
  }
  const feesDoc = await firestoreGet(env, 'settings/fees', token);
  const fees = feesDoc?.data || {};
  const commissionPercent = Number(fees.commissionPercent ?? 5);
  const deliveryPayout = Number(fees.deliveryPayout ?? 30);
  const customerDeliveryCharge = Number(fees.customerDeliveryCharge ?? 0);
  const platformFee = Number(fees.platformFee ?? 0);
  const deliveryPayer = fees.deliveryPayer || 'company';

  if (
    ![commissionPercent, deliveryPayout, customerDeliveryCharge, platformFee].every(Number.isFinite) ||
    commissionPercent < 0 || commissionPercent > 100 ||
    deliveryPayout < 0 || customerDeliveryCharge < 0 || platformFee < 0 ||
    !['company', 'customer', 'shopkeeper', 'split'].includes(deliveryPayer)
  ) {
    throw new Error('Saved fee settings are invalid. Ask Admin to correct them.');
  }

  const prepared = [];
  const productWrites = [];

  for (const group of groups) {
    const shopDoc = await firestoreGet(env, `shops/${encodeURIComponent(group.shopId)}`, token);
    const shop = shopDoc?.data || {};
    if (!shopDoc || shop.approved !== true || shop.active !== true || shop.isOpen === false || !shop.ownerId) {
      throw Object.assign(new Error(`Shop ${group.shopId} is not active.`), { status: 409 });
    }
    if (paymentMethod === 'cod' && (shop.codEnabled === false || shop.codDisabled === true)) {
      throw Object.assign(new Error(`${shop.name || 'इस दुकान'} पर Cash on Delivery बंद है। कृपया Online Payment चुनें।`), { status: 409 });
    }

    const orderItems = [];
    let subtotal = 0;
    for (const item of group.items) {
      const productId = String(item.productId);
      const quantity = Number(item.quantity);
      const productDoc = await firestoreGet(env, `products/${encodeURIComponent(productId)}`, token);
      const product = productDoc?.data || {};

      if (!productDoc || product.shopId !== group.shopId || product.ownerId !== shop.ownerId) {
        throw Object.assign(new Error(`यह सामान उपलब्ध नहीं है: ${product.name || productId}`), { status: 409 });
      }

      const price = Number(product.price);
      const stock = Number(product.stock ?? 0);
      if (!Number.isFinite(stock) || !Number.isInteger(stock) || stock < 0) {
        throw Object.assign(new Error(`${product.name || 'इस सामान'} का स्टॉक रिकॉर्ड सही नहीं है। दुकानदार से संपर्क करें।`), { status: 409 });
      }
      if (stock < quantity) {
        throw Object.assign(new Error(`${product.name || 'यह सामान'} का पर्याप्त स्टॉक नहीं है। अभी केवल ${stock} उपलब्ध हैं; कार्ट अपडेट करें।`), { status: 409 });
      }
      if (product.active !== true || stock === 0) {
        throw Object.assign(new Error(`${product.name || 'यह सामान'} अभी Out of Stock है। इसे ऑर्डर नहीं किया जा सकता।`), { status: 409 });
      }
      if (!Number.isFinite(price) || price < 0) {
        throw Object.assign(new Error(`${product.name || 'इस सामान'} की कीमत सही नहीं है।`), { status: 409 });
      }

      const lineTotal = roundMoney(price * quantity);
      subtotal = roundMoney(subtotal + lineTotal);
      orderItems.push({
        productId,
        name: String(product.name || 'Product'),
        price,
        quantity,
        unit: String(product.unit || 'piece'),
        total: lineTotal,
      });

      productWrites.push({
        update: {
          name: documentName(env, `products/${encodeURIComponent(productId)}`),
          fields: encodeFields({
            stock: stock - quantity,
            active: stock - quantity > 0,
            updatedAt: new Date(),
          }),
        },
        updateMask: { fieldPaths: ['stock', 'active', 'updatedAt'] },
        currentDocument: { updateTime: productDoc.updateTime },
      });
    }

    const commission = roundMoney(subtotal * commissionPercent / 100);
    const deliveryCharge = deliveryPayer === 'customer'
      ? deliveryPayout
      : deliveryPayer === 'split' ? deliveryPayout / 2 : 0;
    const customerTotal = roundMoney(
      subtotal + customerDeliveryCharge + platformFee + deliveryCharge,
    );

    prepared.push({
      orderId: crypto.randomUUID(),
      shopId: group.shopId,
      shopkeeperId: shop.ownerId,
      items: orderItems,
      subtotal,
      commission,
      deliveryCharge,
      customerTotal,
      estimatedDeliveryMinutes: Number.isFinite(Number(shop.estimatedDeliveryMinutes)) && Number(shop.estimatedDeliveryMinutes) > 0 ? Number(shop.estimatedDeliveryMinutes) : null,
    });
  }

  const now = new Date();
  const couponCode = String(body.couponCode || '').trim().toUpperCase();
  let couponDiscount = 0;
  if (couponCode) {
    if (!/^[A-Z0-9_-]{3,30}$/.test(couponCode)) throw Object.assign(new Error('Coupon code sahi nahi hai.'), { status: 400 });
    const couponDoc = await firestoreGet(env, `coupons/${encodeURIComponent(couponCode)}`, token);
    const coupon = couponDoc?.data || {};
    if (!couponDoc || coupon.active !== true) throw Object.assign(new Error('Coupon available nahi hai.'), { status: 400 });
    const startAt = coupon.startAt ? Date.parse(coupon.startAt) : NaN;
    const endAt = coupon.endAt ? Date.parse(coupon.endAt) : NaN;
    if (coupon.startAt && !Number.isFinite(startAt)) throw Object.assign(new Error('Coupon start date setting galat hai.'), { status: 400 });
    if (coupon.endAt && !Number.isFinite(endAt)) throw Object.assign(new Error('Coupon end date setting galat hai.'), { status: 400 });
    if (Number.isFinite(startAt) && now.getTime() < startAt) throw Object.assign(new Error('Coupon abhi shuru nahi hua.'), { status: 400 });
    if (Number.isFinite(endAt) && now.getTime() > endAt) throw Object.assign(new Error('Coupon ki validity khatam ho gayi.'), { status: 400 });
    const subtotalAll = roundMoney(prepared.reduce((sum, order) => sum + order.subtotal, 0));
    const minimum = Number(coupon.minimumOrder ?? 0);
    if (subtotalAll <= 0) throw Object.assign(new Error('Zero amount order par coupon nahi lag sakta.'), { status: 400 });
    if (!Number.isFinite(minimum) || minimum < 0 || subtotalAll < minimum) throw Object.assign(new Error(`Coupon ke liye minimum order ₹${minimum} hona chahiye.`), { status: 400 });
    const value = Number(coupon.discountValue || 0);
    if (!Number.isFinite(value) || value <= 0 || (coupon.discountType === 'percentage' && value > 100)) throw Object.assign(new Error('Coupon discount setting galat hai.'), { status: 400 });
    if (coupon.discountType === 'percentage') couponDiscount = subtotalAll * value / 100;
    else if (coupon.discountType === 'fixed') couponDiscount = value;
    else throw Object.assign(new Error('Coupon discount type galat hai.'), { status: 400 });
    if (coupon.maximumDiscount != null) {
      const maxDiscount = Number(coupon.maximumDiscount);
      if (!Number.isFinite(maxDiscount) || maxDiscount < 0) throw Object.assign(new Error('Coupon maximum discount setting galat hai.'), { status: 400 });
      couponDiscount = Math.min(couponDiscount, maxDiscount);
    }
    couponDiscount = roundMoney(Math.max(0, Math.min(couponDiscount, subtotalAll)));
    let remainingDiscount = couponDiscount;
    for (let i = 0; i < prepared.length; i++) {
      const order = prepared[i];
      const share = i === prepared.length - 1 ? remainingDiscount : roundMoney(couponDiscount * order.subtotal / subtotalAll);
      const applied = Math.min(order.customerTotal, share, remainingDiscount);
      order.couponDiscount = roundMoney(applied);
      order.customerTotal = roundMoney(Math.max(0, order.customerTotal - applied));
      remainingDiscount = roundMoney(remainingDiscount - applied);
    }
  }
  const beforeWalletTotal = roundMoney(prepared.reduce((sum, order) => sum + order.customerTotal, 0));
  const availablePoints = Math.max(0, Math.floor(Number(customerProfile?.data?.pointsBalance) || 0));
  const requestedWalletUse = body.useWalletPoints === true;
  // Google-served rewarded-ad discounts for physical goods must not exceed
  // 25% of the value of the items in the order. Keep the same cap on the
  // server even if a modified client requests more points.
  const eligibleItemSubtotal = roundMoney(prepared.reduce((sum, order) => sum + order.subtotal, 0));
  const maxRewardDiscount = roundMoney(eligibleItemSubtotal * 0.25);
  const walletPointsRedeemed = requestedWalletUse
    ? Math.min(availablePoints, Math.floor(beforeWalletTotal * 100 + 0.000001), Math.floor(maxRewardDiscount * 100 + 0.000001))
    : 0;
  const walletDiscount = roundMoney(walletPointsRedeemed / 100);
  let remainingWalletDiscount = walletDiscount;
  for (let i = 0; i < prepared.length; i++) {
    const order = prepared[i];
    const share = i === prepared.length - 1
      ? remainingWalletDiscount
      : roundMoney(walletDiscount * (beforeWalletTotal > 0 ? order.customerTotal / beforeWalletTotal : 0));
    const applied = roundMoney(Math.min(order.customerTotal, share, remainingWalletDiscount));
    order.walletDiscount = applied;
    order.walletPointsRedeemed = Math.round(applied * 100);
    order.customerTotal = roundMoney(Math.max(0, order.customerTotal - applied));
    remainingWalletDiscount = roundMoney(Math.max(0, remainingWalletDiscount - applied));
  }
  const afterWalletTotal = roundMoney(prepared.reduce((sum, order) => sum + order.customerTotal, 0));
  const fullyCoveredByWallet = walletPointsRedeemed > 0 && afterWalletTotal <= 0;
  const effectivePaymentMethod = fullyCoveredByWallet ? 'wallet' : paymentMethod;
  if (effectivePaymentMethod === 'paytm') paytmConfig(env);
  const paymentSessionId = effectivePaymentMethod === 'paytm' ? `SB${crypto.randomUUID().replace(/-/g, '')}` : '';
  const writes = [...productWrites];
  if (walletPointsRedeemed > 0) {
    writes.push({
      update: { name: documentName(env, `users/${encodeURIComponent(uid)}`), fields: encodeFields({ pointsBalance: availablePoints - walletPointsRedeemed, pointsUpdatedAt: now }) },
      updateMask: { fieldPaths: ['pointsBalance', 'pointsUpdatedAt'] },
      currentDocument: { updateTime: customerProfile.updateTime },
    });
  }
  for (const order of prepared) {
    const orderData = {
      customerId: uid,
      shopId: order.shopId,
      shopkeeperId: order.shopkeeperId,
      items: order.items,
      address: body.address.trim(),
      customerName: String(body.customerName || '').trim(),
      customerPhone: String(body.customerPhone || '').trim(),
      ...(Number.isFinite(latitude) && Number.isFinite(longitude) ? { customerLocation: { latitude, longitude } } : {}),
      pinCode,
      deliveryMode: 'app',
      deliveryAssignmentStatus: 'waiting_shopkeeper',
      deliveryRejectedIds: [],
      paymentMethod: effectivePaymentMethod,
      paymentStatus: fullyCoveredByWallet ? 'paid' : 'pending',
      status: effectivePaymentMethod === 'paytm' ? 'pending_payment' : 'placed',
      walletPointsRedeemed: order.walletPointsRedeemed || 0,
      walletDiscount: order.walletDiscount || 0,
      ...(paymentSessionId ? { paymentSessionId, paymentGatewayOrderId: paymentSessionId } : {}),
      subtotal: order.subtotal,
      commissionAmount: order.commission,
      commissionPercentSnapshot: commissionPercent,
      deliveryPayoutSnapshot: deliveryPayout,
      customerDeliveryChargeSnapshot: customerDeliveryCharge,
      platformFeeSnapshot: platformFee,
      deliveryPayerSnapshot: deliveryPayer,
      deliveryChargeSnapshot: order.deliveryCharge,
      couponCode: couponCode || '',
      couponDiscount: order.couponDiscount || 0,
      estimatedDeliveryMinutes: order.estimatedDeliveryMinutes,
      customerTotal: order.customerTotal,
      createdAt: now,
      updatedAt: now,
    };
    writes.push({
      update: {
        name: documentName(env, `orders/${order.orderId}`),
        fields: encodeFields(orderData),
      },
      currentDocument: { exists: false },
    });
    if (order.walletPointsRedeemed > 0) {
      const redemptionId = `redeem_${order.orderId}`;
      writes.push({
        update: { name: documentName(env, `reward_transactions/${encodeURIComponent(redemptionId)}`), fields: encodeFields({ userId: uid, points: -order.walletPointsRedeemed, rupeeValue: -order.walletDiscount, source: 'checkout_redemption', orderId: order.orderId, createdAt: now }) },
        currentDocument: { exists: false },
      });
    }
  }

  if (paymentSessionId) {
    const amount = roundMoney(prepared.reduce((sum, order) => sum + order.customerTotal, 0));
    writes.push({ update: { name: documentName(env, `payment_sessions/${paymentSessionId}`), fields: encodeFields({ customerId: uid, orderIds: prepared.map(o => o.orderId), amount, paymentStatus: 'pending', gateway: 'paytm', createdAt: now, updatedAt: now }) }, currentDocument: { exists: false } });
  }

  if (writes.length > 500) {
    throw Object.assign(new Error('Cart is too large for one safe order transaction.'), { status: 400 });
  }
  await firestoreCommit(env, writes, token);

  const total = {
    success: true,
    ...(paymentSessionId ? { paymentSessionId } : {}),
    paymentMethod: effectivePaymentMethod,
    orders: prepared.map(o => ({
      orderId: o.orderId,
      shopId: o.shopId,
      subtotal: o.subtotal,
      commission: o.commission,
      deliveryPayout,
      customerTotal: o.customerTotal,
    })),
    orderIds: prepared.map(o => o.orderId),
    subtotal: roundMoney(prepared.reduce((s, o) => s + o.subtotal, 0)),
    commission: roundMoney(prepared.reduce((s, o) => s + o.commission, 0)),
    deliveryPayout: roundMoney(deliveryPayout * prepared.length),
    couponCode: couponCode || '',
    couponDiscount,
    walletPointsRedeemed,
    walletDiscount,
    customerTotal: roundMoney(prepared.reduce((s, o) => s + o.customerTotal, 0)),
  };
  if (prepared.length === 1) Object.assign(total, total.orders[0]);
  return json(total);
}


async function otpEmailKey(email) {
  const bytes = new TextEncoder().encode(email.toLowerCase());
  const digest = await crypto.subtle.digest('SHA-256', bytes);
  return Array.from(new Uint8Array(digest)).map(b => b.toString(16).padStart(2, '0')).join('');
}

async function otpCodeHash(email, code, env) {
  if (!env.OTP_HASH_SECRET) {
    throw Object.assign(new Error('OTP_HASH_SECRET Worker secret is missing.'), { status: 503 });
  }
  const bytes = new TextEncoder().encode(`${email.toLowerCase()}|${code}|${env.OTP_HASH_SECRET}`);
  const digest = await crypto.subtle.digest('SHA-256', bytes);
  return Array.from(new Uint8Array(digest)).map(b => b.toString(16).padStart(2, '0')).join('');
}

async function sendRegistrationOtp(request, env) {
  const body = await request.json();
  const email = String(body.email || '').trim().toLowerCase();
  if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) {
    throw Object.assign(new Error('सही ईमेल एड्रेस डालें।'), { status: 400 });
  }
  if (!env.BYTELABS_MAIL_KEY || !env.BYTELABS_FROM_EMAIL) {
    throw Object.assign(new Error('ByteLabs सेटअप अधूरा है। Cloudflare में BYTELABS_MAIL_KEY और BYTELABS_FROM_EMAIL सेट करें।'), { status: 503 });
  }

  const token = await googleAccessToken(env);
  const docId = await otpEmailKey(email);
  const path = `email_registration_otps/${docId}`;
  const previous = await firestoreGet(env, path, token);
  const now = Date.now();
  const recentStart = previous ? Number(previous.data.windowStartedAt || 0) : 0;
  const recentCount = previous && now - recentStart < 15 * 60 * 1000
    ? Number(previous.data.sendCount || 0) : 0;
  if (previous && now < Number(previous.data.resendAt || 0)) {
    const wait = Math.ceil((Number(previous.data.resendAt) - now) / 1000);
    throw Object.assign(new Error(`नया OTP भेजने के लिए ${wait} सेकंड रुकें।`), { status: 429 });
  }
  if (recentCount >= 5) {
    throw Object.assign(new Error('बहुत बार OTP माँगा गया है। 15 मिनट बाद फिर कोशिश करें।'), { status: 429 });
  }

  const random = new Uint32Array(1);
  crypto.getRandomValues(random);
  const otp = String(random[0] % 1000000).padStart(6, '0');
  const codeHash = await otpCodeHash(email, otp, env);
  const expiresAt = now + 5 * 60 * 1000;
  const record = {
    email,
    codeHash,
    expiresAt,
    resendAt: now + 60 * 1000,
    windowStartedAt: recentCount ? recentStart : now,
    sendCount: recentCount + 1,
    attempts: 0,
    verified: false,
    createdAt: new Date(now),
  };
  const write = {
    update: { name: documentName(env, path), fields: encodeFields(record) },
    updateMask: { fieldPaths: Object.keys(record) },
  };
  if (previous) write.currentDocument = { updateTime: previous.updateTime };
  else write.currentDocument = { exists: false };
  await firestoreCommit(env, [write], token);

  const mail = await fetch('https://api.bytelabs.co.in/mail/api/v1/emails', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${env.BYTELABS_MAIL_KEY}`,
      'Content-Type': 'application/json',
      'User-Agent': 'Sanchore-Bazaar-Worker/1.0',
      'Idempotency-Key': `registration-otp-${docId}-${now}`,
    },
    body: JSON.stringify({
      from: env.BYTELABS_FROM_EMAIL,
      to: [email],
      subject: 'Sanchore Bazaar - Email Verification OTP',
      html: `<div style="font-family:Arial,sans-serif;max-width:520px;margin:auto;padding:24px;border:1px solid #eee;border-radius:14px;text-align:center"><img src="https://sanchorebazaar.bg5.net/email-logo.png" alt="Sanchore Bazaar" width="88" height="88" style="display:block;width:88px;height:88px;object-fit:contain;margin:0 auto 14px;border-radius:18px"><h2 style="margin:0 0 18px;color:#243b2b">Sanchore Bazaar</h2><p>आपका ईमेल सत्यापन OTP है:</p><div style="font-size:32px;font-weight:700;letter-spacing:8px;padding:18px;background:#f5f5f5;text-align:center;border-radius:10px">${otp}</div><p>यह OTP 5 मिनट में समाप्त हो जाएगा। इसे किसी के साथ साझा न करें।</p><p style="font-size:12px;color:#777">Sanchore Bazaar · आपका स्थानीय बाज़ार</p></div>`,
      text: `Sanchore Bazaar email verification OTP: ${otp}. This OTP expires in 5 minutes. Do not share it.`,
    }),
  });
  const mailData = await mail.json().catch(() => ({}));
  if (!mail.ok) {
    const detail = mailData?.error?.message || mailData?.error?.code || `HTTP ${mail.status}`;
    throw Object.assign(new Error(`ByteLabs से OTP ईमेल नहीं भेजा जा सका: ${detail}`), { status: mail.status === 429 ? 429 : 502 });
  }
  return json({ success: true, message: 'OTP आपके ईमेल पर भेज दिया गया है।', expiresIn: 300, resendAfter: 60 });
}

async function verifyRegistrationOtp(request, env) {
  const body = await request.json();
  const email = String(body.email || '').trim().toLowerCase();
  const code = String(body.otp || '').trim();
  if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email) || !/^\d{6}$/.test(code)) {
    throw Object.assign(new Error('6 अंकों का सही OTP डालें।'), { status: 400 });
  }
  const token = await googleAccessToken(env);
  const docId = await otpEmailKey(email);
  const path = `email_registration_otps/${docId}`;
  const record = await firestoreGet(env, path, token);
  if (!record) throw Object.assign(new Error('पहले OTP भेजें।'), { status: 404 });
  const now = Date.now();
  if (record.data.verified === true) return json({ success: true, verified: true });
  if (now > Number(record.data.expiresAt || 0)) {
    throw Object.assign(new Error('OTP समाप्त हो गया है। नया OTP भेजें।'), { status: 410 });
  }
  const attempts = Number(record.data.attempts || 0);
  if (attempts >= 5) throw Object.assign(new Error('बहुत गलत प्रयास हुए। नया OTP भेजें।'), { status: 429 });
  const submittedHash = await otpCodeHash(email, code, env);
  const expected = String(record.data.codeHash || '');
  if (submittedHash !== expected) {
    const nextAttempts = attempts + 1;
    await firestoreCommit(env, [{
      update: { name: documentName(env, path), fields: encodeFields({ attempts: nextAttempts }) },
      updateMask: { fieldPaths: ['attempts'] },
      currentDocument: { updateTime: record.updateTime },
    }], token);
    throw Object.assign(new Error(`OTP गलत है। ${5 - nextAttempts} प्रयास बाकी हैं।`), { status: 400 });
  }
  await firestoreCommit(env, [{
    update: { name: documentName(env, path), fields: encodeFields({ verified: true, verifiedAt: now }) },
    updateMask: { fieldPaths: ['verified', 'verifiedAt'] },
    currentDocument: { updateTime: record.updateTime },
  }], token);
  return json({ success: true, verified: true, message: 'ईमेल सत्यापित हो गया। अब रजिस्ट्रेशन पूरा करें।' });
}

async function saveDocument(env, path, data, token, createOnly = false) {
  const write = {
    update: {
      name: documentName(env, path),
      fields: encodeFields(data),
    },
    updateMask: { fieldPaths: Object.keys(data) },
  };
  if (createOnly) {
    write.currentDocument = { exists: false };
  } else {
    const current = await firestoreGet(env, path, token);
    if (!current) throw Object.assign(new Error('Record not found.'), { status: 404 });
    write.currentDocument = { updateTime: current.updateTime };
  }
  await firestoreCommit(env, [write], token);
}


async function assertAuthenticatedRegistrationEmail(request, env, uid, email) {
  // Firebase Auth is the source of identity. No registration OTP email is used.
  const normalizedEmail = String(email || '').trim().toLowerCase();
  if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(normalizedEmail)) {
    throw Object.assign(new Error('सही ईमेल एड्रेस जरूरी है।'), { status: 400 });
  }
  const match = String(request.headers.get('Authorization') || '').match(/^Bearer\s+(.+)$/i);
  if (!match) throw Object.assign(new Error('Login token required.'), { status: 401 });
  const lookup = await fetch(`https://identitytoolkit.googleapis.com/v1/accounts:lookup?key=${encodeURIComponent(env.FIREBASE_WEB_API_KEY)}`, {
    method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ idToken: match[1] }),
  });
  const identity = await lookup.json();
  const firebaseUser = identity.users?.[0];
  if (!lookup.ok || !firebaseUser || firebaseUser.localId !== uid || String(firebaseUser.email || '').toLowerCase() !== normalizedEmail) {
    throw Object.assign(new Error('Firebase खाते की पहचान सत्यापित नहीं हो सकी।'), { status: 403 });
  }
  return { email: normalizedEmail, token: match[1] };
}

async function registerCustomerProfile(request, env, uid, token) {
  const body = await request.json();
  const name = String(body.name || '').trim();
  const phone = String(body.phone || '').trim();
  if (name.length < 2 || !/^\d{10}$/.test(phone)) {
    throw Object.assign(new Error('सही नाम और 10 अंकों का मोबाइल नंबर डालें।'), { status: 400 });
  }
  const verified = await assertAuthenticatedRegistrationEmail(request, env, uid, body.email);
  const path = `users/${encodeURIComponent(uid)}`;
  const existing = await firestoreGet(env, path, token);
  if (existing) {
    if (existing.data.role === 'customer' && String(existing.data.email || '').toLowerCase() === verified.email) {
      return json({ success: true, alreadyRegistered: true });
    }
    throw Object.assign(new Error('इस Firebase खाते का प्रोफाइल पहले से मौजूद है।'), { status: 409 });
  }
  await saveDocument(env, path, {
    uid, name, phone, email: verified.email, role: 'customer', approved: true,
    emailVerified: false, active: true, pointsBalance: 0, createdAt: new Date(),
  }, token, true);
  return json({ success: true });
}

async function applyStaffRegistration(request, env, uid, token) {
  const body = await request.json();
  const role = String(body.role || '');
  const name = String(body.name || '').trim();
  const phone = String(body.phone || '').trim();
  const verifiedEmail = await assertAuthenticatedRegistrationEmail(request, env, uid, body.email);

  if (!['shopkeeper', 'delivery'].includes(role) ||
      name.length < 2 || phone.length < 8 || phone.length > 15) {
    throw Object.assign(
      new Error('Valid name, phone and staff role are required.'),
      { status: 400 },
    );
  }

  const existing = await firestoreGet(env, `users/${encodeURIComponent(uid)}`, token);
  if (existing) {
    if (existing.data.role === role && existing.data.approved === false &&
        existing.data.applicationStatus === 'pending') {
      return json({ success: true, message: 'Staff application is already pending.' });
    }
    throw Object.assign(new Error('User profile already exists.'), { status: 409 });
  }

  await saveDocument(env, `users/${encodeURIComponent(uid)}`, {
    uid,
    name,
    phone,
    email: verifiedEmail.email,
    role,
    approved: false,
    active: true,
    applicationStatus: 'pending',
    emailVerified: false,
    createdAt: new Date(),
  }, token, true);

  return json({ success: true, message: 'Staff application submitted. Admin approval required.' });
}

async function approveStaff(request, env, uid, token) {
  await requireRole(env, uid, token, 'admin');
  const body = await request.json();
  const targetId = String(body.userId || '');
  const approved = body.approved === true;
  const user = await firestoreGet(env, `users/${encodeURIComponent(targetId)}`, token);

  if (!user || !['shopkeeper', 'delivery'].includes(user.data.role)) {
    throw Object.assign(new Error('Staff user not found.'), { status: 404 });
  }

  await saveDocument(env, `users/${encodeURIComponent(targetId)}`, {
    approved,
    reviewedBy: uid,
    reviewedAt: new Date(),
    active: approved,
    applicationStatus: approved ? 'approved' : 'rejected',
  }, token);

  return json({ success: true, message: approved ? 'Staff approved.' : 'Staff rejected.' });
}

async function adminListCodAccounts(request, env, uid, token) {
  await requireRole(env, uid, token, 'admin');
  const [users, shops] = await Promise.all([
    firestoreList(env, 'users', token, 1000),
    firestoreList(env, 'shops', token, 1000),
  ]);
  const customers = users.filter(x => x.data.role === 'customer').map(x => ({
    id: x.id, name: x.data.name || x.data.phone || 'ग्राहक', phone: x.data.phone || '',
    codEnabled: x.data.codEnabled !== false && x.data.codDisabled !== true,
  }));
  const shopRows = shops.filter(x => x.data.approved === true).map(x => ({
    id: x.id, name: x.data.name || 'दुकान', phone: x.data.phone || '',
    codEnabled: x.data.codEnabled !== false && x.data.codDisabled !== true,
  }));
  return json({ success: true, customers, shops: shopRows });
}

async function adminSetCodOverride(request, env, uid, token) {
  await requireRole(env, uid, token, 'admin');
  const b = await request.json();
  const type = String(b.targetType || '');
  const id = String(b.targetId || '').trim();
  const enabled = b.enabled === true;
  if (!id || !['customer', 'shop'].includes(type)) throw Object.assign(new Error('ग्राहक या दुकान चुनें।'), { status: 400 });
  const collection = type === 'customer' ? 'users' : 'shops';
  const target = await firestoreGet(env, `${collection}/${encodeURIComponent(id)}`, token);
  if (!target || (type === 'customer' && target.data.role !== 'customer')) throw Object.assign(new Error('रिकॉर्ड नहीं मिला।'), { status: 404 });
  if (type === 'shop' && target.data.approved !== true) throw Object.assign(new Error('स्वीकृत दुकान नहीं मिली।'), { status: 404 });
  await saveDocument(env, `${collection}/${encodeURIComponent(id)}`, {
    codEnabled: enabled, codDisabled: !enabled,
    codDisabledReason: enabled ? '' : 'admin_manual_override',
    codUpdatedBy: uid, codUpdatedAt: new Date(),
  }, token);
  return json({ success: true, enabled });
}

async function adminDeactivateStaff(request, env, uid, token) {
  await requireRole(env, uid, token, 'admin');
  const b = await request.json();
  const targetId = String(b.userId || '').trim();
  const target = await firestoreGet(env, `users/${encodeURIComponent(targetId)}`, token);
  if (!target || !['shopkeeper', 'delivery'].includes(target.data.role)) throw Object.assign(new Error('दुकानदार/डिलीवरी बॉय नहीं मिला।'), { status: 404 });
  await saveDocument(env, `users/${encodeURIComponent(targetId)}`, {
    active: false, approved: false, applicationStatus: 'disabled', disabledBy: uid, disabledAt: new Date(),
  }, token);
  if (target.data.role === 'shopkeeper') {
    const shops = await firestoreList(env, 'shops', token, 1000);
    for (const item of shops.filter(x => x.data.ownerId === targetId && x.data.active !== false)) {
      await saveDocument(env, `shops/${encodeURIComponent(item.id)}`, { active: false, disabledBy: uid, disabledAt: new Date() }, token);
    }
  }
  return json({ success: true, message: 'खाता बंद कर दिया गया।' });
}

async function adminReactivateStaff(request, env, uid, token) {
  await requireRole(env, uid, token, 'admin');
  const b = await request.json();
  const targetId = String(b.userId || '').trim();
  const target = await firestoreGet(env, `users/${encodeURIComponent(targetId)}`, token);
  if (!target || !['shopkeeper', 'delivery'].includes(target.data.role)) throw Object.assign(new Error('दुकानदार/डिलीवरी बॉय नहीं मिला।'), { status: 404 });
  const now = new Date();
  await saveDocument(env, `users/${encodeURIComponent(targetId)}`, {
    active: true, approved: true, applicationStatus: 'approved', reactivatedBy: uid, reactivatedAt: now,
  }, token);
  if (target.data.role === 'shopkeeper') {
    const shops = await firestoreList(env, 'shops', token, 1000);
    for (const item of shops.filter(x => x.data.ownerId === targetId && x.data.approved === true)) {
      await saveDocument(env, `shops/${encodeURIComponent(item.id)}`, { active: true, reactivatedBy: uid, reactivatedAt: now }, token);
    }
  }
  return json({ success: true, message: 'खाता फिर से सक्रिय कर दिया गया।' });
}

async function adminListServiceAreas(request, env, uid, token) {
  await requireRole(env, uid, token, 'admin');
  const docs = await firestoreList(env, 'service_areas', token, 1000);
  return json({ success: true, areas: docs.map(x => ({ areaId: x.id, ...x.data })) });
}

async function adminAddServiceArea(request, env, uid, token) {
  await requireRole(env, uid, token, 'admin');
  const b = await request.json();
  const name = String(b.name || '').trim().slice(0, 100);
  const pinCode = String(b.pinCode || '').trim();
  const now = new Date();
  if (pinCode) {
    if (!/^\d{6}$/.test(pinCode)) throw Object.assign(new Error('सही 6 अंकों का PIN कोड भरें।'), { status: 400 });
    const all = await firestoreList(env, 'service_areas', token, 1000);
    if (all.some(x => String(x.data.pinCode || '') === pinCode)) throw Object.assign(new Error('यह PIN कोड पहले से जुड़ा है।'), { status: 409 });
    const areaId = crypto.randomUUID();
    await saveDocument(env, `service_areas/${areaId}`, { name: name || `PIN ${pinCode}`, pinCode, active: true, createdBy: uid, createdAt: now }, token, true);
    return json({ success: true, areaId });
  }
  const latitude = Number(b.latitude), longitude = Number(b.longitude), radiusKm = Number(b.radiusKm);
  if (!name || !Number.isFinite(latitude) || latitude < -90 || latitude > 90 || !Number.isFinite(longitude) || longitude < -180 || longitude > 180 || !Number.isFinite(radiusKm) || radiusKm <= 0 || radiusKm > 100) throw Object.assign(new Error('क्षेत्र की जानकारी सही भरें।'), { status: 400 });
  const areaId = crypto.randomUUID();
  await saveDocument(env, `service_areas/${areaId}`, { name, center: { latitude, longitude }, radiusKm, active: true, createdBy: uid, createdAt: now }, token, true);
  return json({ success: true, areaId });
}

async function adminUpdateServiceArea(request, env, uid, token) {
  await requireRole(env, uid, token, 'admin');
  const b = await request.json(); const areaId = String(b.areaId || '').trim();
  if (!areaId || typeof b.active !== 'boolean') throw Object.assign(new Error('क्षेत्र और स्थिति चुनें।'), { status: 400 });
  await saveDocument(env, `service_areas/${encodeURIComponent(areaId)}`, { active: b.active, updatedAt: new Date() }, token);
  return json({ success: true });
}

async function adminDeleteServiceArea(request, env, uid, token) {
  await requireRole(env, uid, token, 'admin');
  const b = await request.json(); const areaId = String(b.areaId || '').trim();
  if (!areaId) throw Object.assign(new Error('क्षेत्र नहीं मिला।'), { status: 400 });
  await firestoreDelete(env, `service_areas/${encodeURIComponent(areaId)}`, token);
  return json({ success: true });
}

async function checkServiceArea(request, env, uid, token) {
  const b = await request.json();
  try {
    await assertServiceArea(env, token, Number.isFinite(Number(b.latitude)) ? Number(b.latitude) : null, Number.isFinite(Number(b.longitude)) ? Number(b.longitude) : null, String(b.pinCode || '').trim());
    return json({ success: true, serviceable: true });
  } catch (error) {
    if ([400, 403].includes(error.status)) return json({ success: true, serviceable: false, message: error.message });
    throw error;
  }
}

async function requestExternalAd(request, env, uid, token) {
  const user = await firestoreGet(env, `users/${encodeURIComponent(uid)}`, token);
  if (!user || user.data.approved !== true || user.data.active === false || user.data.role !== 'shopkeeper') throw Object.assign(new Error('सक्रिय दुकानदार लॉगिन जरूरी है।'), { status: 403 });
  const b = await request.json();
  const businessName = String(b.businessName || '').trim();
  const phone = String(b.phone || '').trim();
  const brief = String(b.brief || '').trim();
  const referenceImageUrl = String(b.referenceImageUrl || '').trim();
  if (businessName.length < 2 || businessName.length > 120 || phone.length < 8 || phone.length > 16 || brief.length < 5 || brief.length > 1500) throw Object.assign(new Error('व्यवसाय का नाम, मोबाइल और प्रचार की जानकारी सही भरें।'), { status: 400 });
  if (referenceImageUrl && !validAdImageUrl(referenceImageUrl)) throw Object.assign(new Error('संदर्भ फोटो का लिंक मान्य नहीं है।'), { status: 400 });
  const requestId = crypto.randomUUID(), now = new Date();
  await saveDocument(env, `ad_requests/${requestId}`, {
    requesterId: uid, requesterRole: user.data.role,
    requesterName: String(user.data.name || ''), businessName, phone, brief,
    referenceImageUrl, status: 'pending', createdAt: now, updatedAt: now,
  }, token, true);
  return json({ success: true, requestId, message: 'विज्ञापन रिक्वेस्ट एडमिन को भेज दी गई।' });
}

async function advertiserMyAdRequests(request, env, uid, token) {
  const user = await firestoreGet(env, `users/${encodeURIComponent(uid)}`, token);
  if (!user || user.data.approved !== true || user.data.active === false || user.data.role !== 'shopkeeper') throw Object.assign(new Error('सक्रिय दुकानदार लॉगिन जरूरी है।'), { status: 403 });
  const docs = await firestoreList(env, 'ad_requests', token, 1000);
  const requests = docs.filter(x => x.data.requesterId === uid).map(x => ({ requestId: x.id, businessName: x.data.businessName || '', brief: x.data.brief || '', status: x.data.status || 'pending', rejectionReason: x.data.rejectionReason || '', createdAt: x.data.createdAt || null, campaignId: x.data.campaignId || '' }));
  requests.sort((a, b) => String(b.createdAt || '').localeCompare(String(a.createdAt || '')));
  return json({ success: true, requests });
}

// ADMIN ONLY: generate ad copy and a clean visual background with Workers AI.
async function adminGenerateAdCreative(request, env, uid, token) {
  await requireRole(env, uid, token, 'admin');
  if (!env.AI || typeof env.AI.run !== 'function') throw Object.assign(new Error('Cloudflare Workers AI binding चालू नहीं है। Worker में AI binding जोड़कर Deploy करें।'), { status: 503 });
  const b = await request.json();
  const businessName = String(b.businessName || '').trim().slice(0, 120);
  const brief = String(b.brief || '').trim().slice(0, 1500);
  if (businessName.length < 2 || brief.length < 5) throw Object.assign(new Error('व्यवसाय का नाम और प्रचार की जानकारी जरूरी है।'), { status: 400 });
  const textPrompt = `आप भारत के छोटे शहर के व्यवसायों के लिए विज्ञापन लेखक हैं। केवल वैध JSON लौटाएँ: {"title":"...","description":"..."}. व्यवसाय: ${businessName}. ग्राहक की जानकारी: ${brief}. भाषा सरल, आकर्षक हिंदी रखें। शीर्षक अधिकतम 55 अक्षर और विवरण अधिकतम 180 अक्षर। कोई झूठा दावा, छूट, फोन नंबर या तथ्य न गढ़ें।`;
  const textResult = await env.AI.run('@cf/meta/llama-3.3-70b-instruct-fp8-fast', { prompt: textPrompt, max_tokens: 220 });
  let generated = String(textResult?.response || textResult?.generated_text || '').trim();
  generated = generated.replace(/^```(?:json)?\s*/i, '').replace(/```\s*$/i, '');
  let copy;
  try { const first = generated.indexOf('{'); const last = generated.lastIndexOf('}'); copy = JSON.parse(first >= 0 && last > first ? generated.slice(first, last + 1) : generated); } catch (_) { copy = { title: businessName, description: generated.slice(0, 180) || brief.slice(0, 180) }; }
  const imagePrompt = `Create a premium, photorealistic advertising background image for an Indian local business in Rajasthan. Business: ${businessName}. Promotion context: ${brief}. Wide horizontal 16:9 composition, polished commercial photography, vibrant but tasteful colors, clean visual hierarchy, leave uncluttered negative space for Hindi headline overlay. Absolutely no text, no letters, no numbers, no logos, no watermark, no fake contact details.`;
  const imageResult = await env.AI.run('@cf/black-forest-labs/flux-1-schnell', { prompt: imagePrompt, steps: 4 });
  const imageBase64 = typeof imageResult?.image === 'string' ? imageResult.image : (Array.isArray(imageResult?.data) && typeof imageResult.data[0] === 'string' ? imageResult.data[0] : '');
  if (!imageBase64) throw Object.assign(new Error('AI ने विज्ञापन फोटो नहीं बनाई। दोबारा कोशिश करें या एडमिन गैलरी से फोटो चुनें।'), { status: 502 });
  return json({ success: true, title: String(copy.title || businessName).slice(0, 100), description: String(copy.description || brief).slice(0, 1000), imageBase64, mimeType: 'image/png' });
}

async function adminListAdRequests(request, env, uid, token) {
  await requireRole(env, uid, token, 'admin');
  const docs = await firestoreList(env, 'ad_requests', token, 1000);
  const requests = docs.filter(x => x.data.status === 'pending').map(x => ({ requestId: x.id, ...x.data }));
  requests.sort((a, b) => String(b.createdAt || '').localeCompare(String(a.createdAt || '')));
  return json({ success: true, requests });
}

async function adminRejectAdRequest(request, env, uid, token) {
  await requireRole(env, uid, token, 'admin');
  const b = await request.json();
  const requestId = String(b.requestId || '').trim();
  const reason = String(b.reason || '').trim().slice(0, 300);
  const path = `ad_requests/${encodeURIComponent(requestId)}`;
  const ref = await firestoreGet(env, path, token);
  if (!ref || ref.data.status !== 'pending') throw Object.assign(new Error('यह रिक्वेस्ट उपलब्ध नहीं है।'), { status: 404 });
  await saveDocument(env, path, { status: 'rejected', rejectionReason: reason || 'एडमिन ने रिक्वेस्ट स्वीकार नहीं की।', reviewedBy: uid, reviewedAt: new Date(), updatedAt: new Date() }, token);
  return json({ success: true, message: 'विज्ञापन रिक्वेस्ट अस्वीकार कर दी गई।' });
}

async function adminCreateAdFromRequest(request, env, uid, token) {
  await requireRole(env, uid, token, 'admin');
  const b = await request.json();
  const requestId = String(b.requestId || '').trim();
  const title = String(b.title || '').trim();
  const description = String(b.description || '').trim();
  const imageUrl = String(b.imageUrl || '').trim();
  const destinationUrl = String(b.destinationUrl || '').trim();
  const placement = String(b.placement || 'banner');
  const packageDays = Number(b.packageDays);
  if (!requestId || !title || title.length > 100 || description.length > 1000 || !validAdImageUrl(imageUrl) || (destinationUrl && !validAdImageUrl(destinationUrl)) || ![7, 15, 30].includes(packageDays) || !['banner', 'shop_featured', 'product_featured', 'local_business'].includes(placement)) {
    throw Object.assign(new Error('विज्ञापन की जानकारी सही भरें।'), { status: 400 });
  }
  const ref = await firestoreGet(env, `ad_requests/${encodeURIComponent(requestId)}`, token);
  if (!ref || ref.data.status !== 'pending') throw Object.assign(new Error('यह रिक्वेस्ट उपलब्ध नहीं है या पहले ही पूरी हो चुकी है।'), { status: 409 });
  const r = ref.data;
  const campaignId = crypto.randomUUID();
  const now = new Date();
  // For a shopkeeper's sponsored shop/product creative, connect the campaign
  // to the first approved active shop owned by that advertiser. External local
  // businesses remain destination-link campaigns.
  let linkedShopId = '';
  if (['shop_featured', 'product_featured'].includes(placement)) {
    const ownedShops = await firestoreList(env, 'shops', token, 1000);
    const owned = ownedShops.find(x => x.data.ownerId === r.requesterId && x.data.approved === true && x.data.active === true);
    if (!owned) throw Object.assign(new Error('प्रायोजित दुकान/सामान के लिए पहले स्वीकृत सक्रिय दुकान जरूरी है।'), { status: 409 });
    linkedShopId = owned.id;
  }
  await saveDocument(env, `ad_campaigns/${campaignId}`, {
    ownerId: r.requesterId, advertiserType: 'external', advertiserName: r.businessName,
    advertiserPhone: r.phone, shopId: linkedShopId, shopName: r.businessName,
    title, description, imageUrl, destinationUrl: destinationUrl || (String(r.phone || '').replace(/\D/g, '').length >= 10 ? `https://wa.me/${String(r.phone).replace(/\D/g, '')}` : ''), referenceImageUrl: r.referenceImageUrl || '',
    placement, packageDays, status: 'draft', paymentStatus: 'not_requested',
    sourceRequestId: requestId, impressionCount: 0, clickCount: 0,
    createdBy: uid, createdAt: now, updatedAt: now,
  }, token, true);
  await saveDocument(env, `ad_requests/${encodeURIComponent(requestId)}`, {
    status: 'converted', campaignId, reviewedBy: uid, reviewedAt: now, updatedAt: now,
  }, token);
  return json({ success: true, campaignId, message: 'Admin-created advertisement draft saved.' });
}

async function requestShopAddition(request, env, uid, token) {
  await requireRole(env, uid, token, 'shopkeeper');
  const user = await firestoreGet(env, `users/${encodeURIComponent(uid)}`, token);
  if (!user || user.data.approved !== true || user.data.active === false) {
    throw Object.assign(new Error('पहले दुकानदार खाते की Admin मंजूरी जरूरी है।'), { status: 403 });
  }
  const b = await request.json();
  const name = String(b.name || '').trim();
  const category = String(b.category || '').trim();
  const address = String(b.address || '').trim();
  const phone = String(b.phone || '').replace(/\D/g, '');
  const ownerName = String(b.ownerName || user.data.name || '').trim();
  const photoUrl = String(b.photoUrl || '').trim();
  if (name.length < 2 || category.length < 2 || address.length < 5 || phone.length < 8 || phone.length > 15 || ownerName.length < 2) {
    throw Object.assign(new Error('दुकान का नाम, श्रेणी, पूरा पता, सही मोबाइल और मालिक का नाम भरें।'), { status: 400 });
  }
  const prior = await firestoreList(env, 'shop_requests', token, 1000);
  const pending = prior.find(x => x.data.ownerId === uid && x.data.status === 'pending');
  if (pending) throw Object.assign(new Error('आपकी एक दुकान जोड़ने की रिक्वेस्ट पहले से लंबित है।'), { status: 409 });
  const requestId = crypto.randomUUID();
  await saveDocument(env, `shop_requests/${requestId}`, {
    ownerId: uid, ownerName, name, category, address, phone, photoUrl,
    status: 'pending', createdAt: new Date(), updatedAt: new Date(),
  }, token, true);
  return json({ success: true, requestId, message: 'दुकान जोड़ने की रिक्वेस्ट Admin को भेज दी गई है।' });
}

async function reviewShopRequest(request, env, uid, token) {
  await requireRole(env, uid, token, 'admin');
  const b = await request.json();
  const requestId = String(b.requestId || '');
  const approved = b.approved === true;
  const reason = String(b.reason || '').trim();
  if (!requestId) throw Object.assign(new Error('रिक्वेस्ट नहीं मिली।'), { status: 400 });
  if (!approved && reason.length < 3) throw Object.assign(new Error('रिजेक्ट करने का कारण लिखें।'), { status: 400 });
  const req = await firestoreGet(env, `shop_requests/${encodeURIComponent(requestId)}`, token);
  if (!req || req.data.status !== 'pending') throw Object.assign(new Error('यह रिक्वेस्ट अब लंबित नहीं है।'), { status: 404 });
  const now = new Date();
  let shopId = '';
  if (approved) {
    shopId = crypto.randomUUID();
    await saveDocument(env, `shops/${shopId}`, {
      name: req.data.name, category: req.data.category, address: req.data.address,
      phone: req.data.phone, photoUrl: req.data.photoUrl || '', ownerName: req.data.ownerName || '',
      ownerId: req.data.ownerId, approved: true, active: true,
      createdAt: now, reviewedBy: uid, reviewedAt: now, sourceRequestId: requestId,
    }, token, true);
  }
  await saveDocument(env, `shop_requests/${encodeURIComponent(requestId)}`, {
    status: approved ? 'approved' : 'rejected', shopId,
    rejectionReason: approved ? '' : reason, reviewedBy: uid, reviewedAt: now, updatedAt: now,
  }, token);
  return json({ success: true, shopId, message: approved ? 'दुकान मंजूर होकर Sanchore Bazaar में जोड़ दी गई।' : 'रिक्वेस्ट रिजेक्ट कर दी गई।' });
}

// Legacy direct shop creation is intentionally blocked. A shop is created only
// inside reviewShopRequest after an Admin approves the shop request.
async function createShop(request, env, uid, token) {
  await requireRole(env, uid, token, 'shopkeeper');
  throw Object.assign(new Error('दुकानदार खुद दुकान नहीं जोड़ सकता। कृपया दुकान जोड़ने की रिक्वेस्ट भेजें।'), { status: 403 });
}

async function approveShop(request, env, uid, token) {
  await requireRole(env, uid, token, 'admin');
  const b = await request.json();
  const shopId = String(b.shopId || '');
  const approved = b.approved === true;
  const shop = await firestoreGet(env, `shops/${encodeURIComponent(shopId)}`, token);

  if (!shop) throw Object.assign(new Error('Shop not found.'), { status: 404 });

  await saveDocument(env, `shops/${encodeURIComponent(shopId)}`, {
    approved,
    active: approved,
    reviewedBy: uid,
    reviewedAt: new Date(),
  }, token);

  return json({ success: true, message: approved ? 'Shop approved.' : 'Shop rejected.' });
}

async function updateShop(request, env, uid, token) {
  await requireRole(env, uid, token, 'shopkeeper');
  const b = await request.json();
  const shopId = String(b.shopId || '');
  const shop = await firestoreGet(env, `shops/${encodeURIComponent(shopId)}`, token);

  if (!shop || shop.data.ownerId !== uid) {
    throw Object.assign(new Error('Shop access denied.'), { status: 403 });
  }

  const name = String(b.name || '').trim();
  const address = String(b.address || '').trim();
  const phone = String(b.phone || '').trim();
  if (name.length < 2 || !address || phone.length < 8) {
    throw Object.assign(new Error('Valid shop name, address and phone are required.'), { status: 400 });
  }

  await saveDocument(env, `shops/${encodeURIComponent(shopId)}`, {
    name, address, phone, updatedAt: new Date(),
  }, token);

  return json({ success: true, message: 'Shop updated.' });
}

async function deactivateShop(request, env, uid, token) {
  await requireRole(env, uid, token, 'shopkeeper');
  const b = await request.json();
  const shopId = String(b.shopId || '');
  const shop = await firestoreGet(env, `shops/${encodeURIComponent(shopId)}`, token);

  if (!shop || shop.data.ownerId !== uid) {
    throw Object.assign(new Error('Shop access denied.'), { status: 403 });
  }

  await saveDocument(env, `shops/${encodeURIComponent(shopId)}`, {
    active: false, updatedAt: new Date(),
  }, token);

  return json({ success: true, message: 'Shop deactivated.' });
}

async function saveProduct(request, env, uid, token) {
  await requireRole(env, uid, token, 'shopkeeper');
  const b = await request.json();
  const productId = String(b.productId || crypto.randomUUID());
  const shopId = String(b.shopId || '');
  const name = String(b.name || '').trim();
  const category = String(b.category || '').trim();
  const unit = String(b.unit || 'piece').trim().toLowerCase();
  const allowedUnits = ['piece', 'kg', 'gram', 'litre', 'ml', 'pack'];
  const price = Number(b.price);
  const stock = Number(b.stock);
  const imageUrl = String(b.imageUrl || '').trim();
  const imageProvided = Object.prototype.hasOwnProperty.call(b, 'imageUrl');
  const imageVerified = b.imageVerified === true;
  const productEmoji = String(b.productEmoji || '').slice(0, 12);
  const productEmojiProvided = Object.prototype.hasOwnProperty.call(b, 'productEmoji');

  const shop = await firestoreGet(env, `shops/${encodeURIComponent(shopId)}`, token);
  if (!shop || shop.data.ownerId !== uid ||
      shop.data.approved !== true || shop.data.active !== true) {
    throw Object.assign(new Error('Approved active shop required.'), { status: 403 });
  }

  if (!name || !category || !allowedUnits.includes(unit) || !Number.isFinite(price) || price <= 0 ||
      !Number.isInteger(stock) || stock < 0 || (imageUrl && !/^https:\/\//i.test(imageUrl))) {
    throw Object.assign(new Error('Invalid product details.'), { status: 400 });
  }

  const old = await firestoreGet(env, `products/${encodeURIComponent(productId)}`, token);
  if (old && (old.data.ownerId !== uid || old.data.shopId !== shopId)) {
    throw Object.assign(new Error('Product access denied.'), { status: 403 });
  }

  const data = {
    shopId, ownerId: uid, name, category, unit, price, stock,
    ...(imageProvided ? { imageUrl } : (old?.data?.imageUrl ? { imageUrl: old.data.imageUrl } : {})),
    imageVerified: imageProvided ? (imageUrl ? imageVerified : false) : (typeof b.imageVerified === 'boolean' ? imageVerified : old?.data?.imageVerified === true),
    productEmoji: productEmojiProvided ? productEmoji : (old?.data?.productEmoji || ''),
    active: stock > 0, updatedAt: new Date(),
  };
  if (!old) data.createdAt = new Date();

  await saveDocument(env, `products/${encodeURIComponent(productId)}`, data, token, !old);
  return json({ success: true, productId, message: old ? 'Product updated.' : 'Product added.' });
}

async function deleteProduct(request, env, uid, token) {
  await requireRole(env, uid, token, 'shopkeeper');
  const b = await request.json();
  const productId = String(b.productId || '');
  const product = await firestoreGet(env, `products/${encodeURIComponent(productId)}`, token);

  if (!product || product.data.ownerId !== uid) {
    throw Object.assign(new Error('Product access denied.'), { status: 403 });
  }

  await saveDocument(env, `products/${encodeURIComponent(productId)}`, {
    active: false, stock: 0, updatedAt: new Date(),
  }, token);

  return json({ success: true, message: 'Product deactivated.' });
}

async function assignDelivery(request, env, uid, token) {
  await requireRole(env, uid, token, 'admin');
  const b = await request.json();
  const orderId = String(b.orderId || '');
  const deliveryBoyId = String(b.deliveryBoyId || '');

  const [order, worker] = await Promise.all([
    firestoreGet(env, `orders/${encodeURIComponent(orderId)}`, token),
    firestoreGet(env, `users/${encodeURIComponent(deliveryBoyId)}`, token),
  ]);

  if (!order || order.data.status !== 'ready' || order.data.deliveryMode === 'external') {
    throw Object.assign(new Error('Order is not ready for delivery.'), { status: 409 });
  }
  if (!worker || worker.data.role !== 'delivery' ||
      worker.data.approved !== true || worker.data.active === false) {
    throw Object.assign(new Error('Approved delivery worker not found.'), { status: 404 });
  }

  const now = new Date();
  await firestoreCommit(env, [
    { update: { name: documentName(env, `orders/${encodeURIComponent(orderId)}`), fields: encodeFields({ deliveryBoyId, status: 'assigned', assignedAt: now, updatedAt: now }) }, updateMask: { fieldPaths: ['deliveryBoyId','status','assignedAt','updatedAt'] }, currentDocument: { updateTime: order.updateTime } },
    { update: { name: documentName(env, `users/${encodeURIComponent(deliveryBoyId)}`), fields: encodeFields({ deliveryAvailable: false, updatedAt: now }) }, updateMask: { fieldPaths: ['deliveryAvailable','updatedAt'] }, currentDocument: { updateTime: worker.updateTime } },
  ], token);

  return json({ success: true, message: 'Delivery assigned.' });
}

async function updateStaffOrder(request, env, uid, token) {
  const b = await request.json();
  const orderId = String(b.orderId || '').trim();
  const status = String(b.status || '').trim();
  if (!orderId) throw Object.assign(new Error('Order ID is required.'), { status: 400 });

  const order = await firestoreGet(env, `orders/${encodeURIComponent(orderId)}`, token);
  if (!order) throw Object.assign(new Error('Order not found.'), { status: 404 });
  const user = await firestoreGet(env, `users/${encodeURIComponent(uid)}`, token);
  if (!user || user.data.approved !== true || user.data.active === false) {
    throw Object.assign(new Error('Approved staff required.'), { status: 403 });
  }

  const current = order.data.status;
  const isShopkeeper = user.data.role === 'shopkeeper' && order.data.shopkeeperId === uid;
  const isDelivery = user.data.role === 'delivery' && order.data.deliveryBoyId === uid;
  let requestedDeliveryMode = null;
  if (isShopkeeper) {
    const allowed = { placed: ['accepted', 'rejected'], accepted: ['preparing'], preparing: ['ready'], ready: ['delivered'] };
    if (!(allowed[current] || []).includes(status)) {
      throw Object.assign(new Error('Invalid shop order status transition.'), { status: 409 });
    }
    if (status === 'accepted') {
      requestedDeliveryMode = String(b.deliveryMode || 'app');
      if (!['app', 'external'].includes(requestedDeliveryMode)) throw Object.assign(new Error('Delivery option invalid.'), { status: 400 });
    }
    if (status === 'delivered' && order.data.deliveryMode !== 'external') {
      throw Object.assign(new Error('App delivery order ko Delivery Boy hi delivered karega.'), { status: 403 });
    }
  } else if (isDelivery) {
    const allowed = { ready: ['picked_up'], picked_up: ['delivered'] };
    if (!(allowed[current] || []).includes(status)) {
      throw Object.assign(new Error('Order shop se READY hone ke baad hi pickup ho sakta hai.'), { status: 409 });
    }
  } else {
    throw Object.assign(new Error('Order access denied.'), { status: 403 });
  }

  const now = new Date();
  const changes = { status, updatedAt: now };
  if (status === 'accepted' && requestedDeliveryMode) {
    changes.deliveryMode = requestedDeliveryMode;
    changes.deliveryAssignmentStatus = requestedDeliveryMode === 'app' ? 'searching' : 'external';
    changes.deliveryRejectedIds = [];
    if (requestedDeliveryMode === 'external') {
      changes.externalDeliveryName = String(b.externalDeliveryName || 'External delivery').slice(0, 80);
      changes.externalDeliveryPhone = String(b.externalDeliveryPhone || '').slice(0, 20);
    }
  }
  if (status === 'delivered') changes.deliveredAt = now;
  if (status === 'rejected') changes.rejectedAt = now;
  const writes = [{
    update: { name: documentName(env, `orders/${encodeURIComponent(orderId)}`), fields: encodeFields(changes) },
    updateMask: { fieldPaths: Object.keys(changes) },
    currentDocument: { updateTime: order.updateTime },
  }];

  // Rejected orders restore every reserved product quantity in the same atomic commit.
  if (status === 'rejected') {
    const items = Array.isArray(order.data.items) ? order.data.items : [];
    if (!items.length) throw Object.assign(new Error('Order items are missing; stock cannot be restored safely.'), { status: 409 });
    for (const item of items) {
      const productId = String(item.productId || '');
      const quantity = Number(item.quantity);
      if (!productId || !Number.isInteger(quantity) || quantity < 1) {
        throw Object.assign(new Error('Order item data is invalid; stock cannot be restored.'), { status: 409 });
      }
      const product = await firestoreGet(env, `products/${encodeURIComponent(productId)}`, token);
      if (!product) throw Object.assign(new Error(`Product ${productId} is missing; ask Admin to restore stock.`), { status: 409 });
      const stock = Number(product.data.stock || 0);
      writes.push({
        update: { name: documentName(env, `products/${encodeURIComponent(productId)}`), fields: encodeFields({ stock: stock + quantity, active: true, updatedAt: now }) },
        updateMask: { fieldPaths: ['stock', 'active', 'updatedAt'] },
        currentDocument: { updateTime: product.updateTime },
      });
    }
  }

  // Delivered orders create immutable, order-keyed settlement/earning records exactly once.
  if (status === 'delivered') {
    const deliveryBoyId = String(order.data.deliveryBoyId || '');
    const isExternal = order.data.deliveryMode === 'external';
    if (!deliveryBoyId && !isExternal) throw Object.assign(new Error('Delivery worker is not assigned.'), { status: 409 });
    const subtotal = Number(order.data.subtotal || 0);
    const commission = Number(order.data.commissionAmount || 0);
    const payout = Number(order.data.deliveryPayoutSnapshot || 0);
    const payer = String(order.data.deliveryPayerSnapshot || 'company');
    if (![subtotal, commission, payout].every(Number.isFinite) || subtotal < 0 || commission < 0 || payout < 0) {
      throw Object.assign(new Error('Order financial snapshot is invalid.'), { status: 409 });
    }
    const shopkeeperDeliveryDeduction = payer === 'shopkeeper' ? payout : payer === 'split' ? payout / 2 : 0;
    const settlementId = encodeURIComponent(orderId);
    const shopkeeperNet = roundMoney(subtotal - commission - shopkeeperDeliveryDeduction);
    const settlement = {
      orderId, shopId: String(order.data.shopId || ''), shopkeeperId: String(order.data.shopkeeperId || ''),
      subtotal, commissionAmount: commission, deliveryDeduction: roundMoney(shopkeeperDeliveryDeduction),
      netAmount: shopkeeperNet, status: 'pending', paid: false, createdAt: now,
    };
    const earning = isExternal ? null : {
      orderId, deliveryBoyId, amount: payout, paid: false, status: 'pending',
      createdAt: now, deliveredAt: now,
    };
    const platform = {
      orderId, shopId: String(order.data.shopId || ''), shopkeeperId: String(order.data.shopkeeperId || ''),
      commissionAmount: commission, deliveryPayout: payout, deliveryPayer: payer,
      customerDeliveryCharge: Number(order.data.customerDeliveryChargeSnapshot || 0),
      platformFee: Number(order.data.platformFeeSnapshot || 0),
      deliveryCharge: Number(order.data.deliveryChargeSnapshot || 0),
      customerTotal: Number(order.data.customerTotal || 0), paymentMethod: String(order.data.paymentMethod || ''), paymentStatus: String(order.data.paymentStatus || 'pending'), transactionId: String(order.data.transactionId || ''), createdAt: now,
    };
    const ledgerRecords = [
      ['shopkeeper_settlements', settlement],
      ['platform_ledger', platform],
    ];
    if (earning) ledgerRecords.push(['delivery_earnings', earning]);
    for (const [collection, data] of ledgerRecords) {
      writes.push({
        update: { name: documentName(env, `${collection}/${settlementId}`), fields: encodeFields(data) },
        currentDocument: { exists: false },
      });
    }
    if (deliveryBoyId) {
      const workerDoc = await firestoreGet(env, `users/${encodeURIComponent(deliveryBoyId)}`, token);
      if (workerDoc) writes.push({
        update: { name: documentName(env, `users/${encodeURIComponent(deliveryBoyId)}`), fields: encodeFields({ deliveryAvailable: true, deliveryOfferOrderId: '', updatedAt: now }) },
        updateMask: { fieldPaths: ['deliveryAvailable', 'deliveryOfferOrderId', 'updatedAt'] },
        currentDocument: { updateTime: workerDoc.updateTime },
      });
    }
  }

  await firestoreCommit(env, writes, token);
  // Dispatch immediately when the shopkeeper marks an app-delivery order READY.
  // Cron remains as a retry mechanism, but the first offer must not wait for the next cron tick.
  if (status === 'ready' && order.data.deliveryMode === 'app') {
    try {
      await processDeliveryOffers(env, token);
    } catch (dispatchError) {
      console.error('Immediate delivery dispatch failed; cron will retry:', dispatchError);
    }
  }
  return json({ success: true, message: 'Order status updated.', stockRestored: status === 'rejected', ledgerCreated: status === 'delivered' });
}

async function recordPurchase(request, env, uid, token) {
  await requireRole(env, uid, token, 'shopkeeper');
  const b = await request.json();
  const productId = String(b.productId || '').trim();
  const quantity = Number(b.quantity);
  const totalCost = Number(b.totalCost);
  if (!productId || !Number.isInteger(quantity) || quantity < 1 || !Number.isFinite(totalCost) || totalCost < 0) {
    throw Object.assign(new Error('Purchase quantity and total cost are invalid.'), { status: 400 });
  }
  const product = await firestoreGet(env, `products/${encodeURIComponent(productId)}`, token);
  if (!product || product.data.ownerId !== uid) throw Object.assign(new Error('Product access denied.'), { status: 403 });
  const stock = Number(product.data.stock || 0);
  const now = new Date();
  const purchaseId = crypto.randomUUID();
  await firestoreCommit(env, [
    { update: { name: documentName(env, `products/${encodeURIComponent(productId)}`), fields: encodeFields({ stock: stock + quantity, active: true, updatedAt: now }) }, updateMask: { fieldPaths: ['stock', 'active', 'updatedAt'] }, currentDocument: { updateTime: product.updateTime } },
    { update: { name: documentName(env, `purchases/${encodeURIComponent(purchaseId)}`), fields: encodeFields({ purchaseId, productId, productName: String(product.data.name || ''), shopId: String(product.data.shopId || ''), shopkeeperId: uid, quantity, totalCost: roundMoney(totalCost), createdAt: now }) }, currentDocument: { exists: false } },
  ], token);
  return json({ success: true, purchaseId, newStock: stock + quantity });
}

async function updateShopSchedule(request, env, uid, token) {
  await requireRole(env, uid, token, 'shopkeeper');
  const b = await request.json();
  const shopId = String(b.shopId || '').trim();
  if (!shopId) throw Object.assign(new Error('Shop ID is required.'), { status: 400 });
  const shop = await firestoreGet(env, `shops/${encodeURIComponent(shopId)}`, token);
  if (!shop || shop.data.ownerId !== uid) throw Object.assign(new Error('Shop access denied.'), { status: 403 });
  const changes = { updatedAt: new Date() };
  if (Object.prototype.hasOwnProperty.call(b, 'weeklySchedule')) {
    if (!b.weeklySchedule || typeof b.weeklySchedule !== 'object' || Array.isArray(b.weeklySchedule)) throw Object.assign(new Error('Weekly schedule is invalid.'), { status: 400 });
    changes.weeklySchedule = b.weeklySchedule;
    changes.holidays = Array.isArray(b.holidays) ? b.holidays.map(String).slice(0, 100) : [];
    changes.scheduleUpdatedAt = new Date();
  }
  if (Object.prototype.hasOwnProperty.call(b, 'isOpen')) changes.isOpen = b.isOpen === true;
  if (Object.prototype.hasOwnProperty.call(b, 'estimatedDeliveryMinutes')) {
    const minutes = Number(b.estimatedDeliveryMinutes);
    if (!Number.isInteger(minutes) || minutes < 5 || minutes > 240) throw Object.assign(new Error('Delivery estimate 5 se 240 minute ke beech hona chahiye.'), { status: 400 });
    changes.estimatedDeliveryMinutes = minutes;
  }
  if (Object.keys(changes).length === 1) throw Object.assign(new Error('No schedule changes supplied.'), { status: 400 });
  await firestoreCommit(env, [{ update: { name: documentName(env, `shops/${encodeURIComponent(shopId)}`), fields: encodeFields(changes) }, updateMask: { fieldPaths: Object.keys(changes) }, currentDocument: { updateTime: shop.updateTime } }], token);
  return json({ success: true });
}

async function reviewCancellation(request, env, uid, token) {
  await requireRole(env, uid, token, 'admin');
  const b = await request.json();
  const requestId = String(b.requestId || '').trim();
  const approve = b.approve === true;
  const ref = await firestoreGet(env, `cancellationRequests/${encodeURIComponent(requestId)}`, token);
  if (!ref || ref.data.status !== 'pending') throw Object.assign(new Error('Pending cancellation request not found.'), { status: 404 });
  const orderId = String(ref.data.orderId || '');
  const order = await firestoreGet(env, `orders/${encodeURIComponent(orderId)}`, token);
  if (!order) throw Object.assign(new Error('Order not found.'), { status: 404 });
  const now = new Date();
  const writes = [];
  if (approve) {
    if (!['placed', 'accepted'].includes(order.data.status)) throw Object.assign(new Error('Order has progressed and can no longer be cancelled.'), { status: 409 });
    const items = Array.isArray(order.data.items) ? order.data.items : [];
    for (const item of items) {
      const productId = String(item.productId || '');
      const quantity = Number(item.quantity);
      if (!productId || !Number.isInteger(quantity) || quantity < 1) throw Object.assign(new Error('Invalid order item; stock restore stopped.'), { status: 409 });
      const product = await firestoreGet(env, `products/${encodeURIComponent(productId)}`, token);
      if (!product) throw Object.assign(new Error(`Product ${productId} is missing; ask Admin to restore stock.`), { status: 409 });
      const stock = Number(product.data.stock || 0);
      writes.push({ update: { name: documentName(env, `products/${encodeURIComponent(productId)}`), fields: encodeFields({ stock: stock + quantity, active: true, updatedAt: now }) }, updateMask: { fieldPaths: ['stock', 'active', 'updatedAt'] }, currentDocument: { updateTime: product.updateTime } });
    }
    writes.push({ update: { name: documentName(env, `orders/${encodeURIComponent(orderId)}`), fields: encodeFields({ status: 'cancelled', cancelledAt: now, cancellationReason: String(ref.data.reason || ''), updatedAt: now }) }, updateMask: { fieldPaths: ['status', 'cancelledAt', 'cancellationReason', 'updatedAt'] }, currentDocument: { updateTime: order.updateTime } });
    // Count admin-approved cancellations against this customer. Disable only this customer's COD after 3 cancellations.
    const customerId = String(order.data.customerId || '');
    if (customerId) {
      const customer = await firestoreGet(env, `users/${encodeURIComponent(customerId)}`, token);
      if (customer) {
        const cancelledCount = Number(customer.data.codCancelledCount || 0) + 1;
        const disableCod = cancelledCount >= 3;
        writes.push({ update: { name: documentName(env, `users/${encodeURIComponent(customerId)}`), fields: encodeFields({ codCancelledCount: cancelledCount, ...(disableCod ? { codEnabled: false, codDisabled: true, codDisabledReason: 'repeated_order_cancellations' } : {}), updatedAt: now }) }, updateMask: { fieldPaths: ['codCancelledCount', ...(disableCod ? ['codEnabled', 'codDisabled', 'codDisabledReason'] : []), 'updatedAt'] }, currentDocument: { updateTime: customer.updateTime } });
      }
    }
  }
  writes.push({ update: { name: documentName(env, `cancellationRequests/${encodeURIComponent(requestId)}`), fields: encodeFields({ status: approve ? 'approved' : 'rejected', adminNote: String(b.adminNote || ''), reviewedBy: uid, reviewedAt: now }) }, updateMask: { fieldPaths: ['status', 'adminNote', 'reviewedBy', 'reviewedAt'] }, currentDocument: { updateTime: ref.updateTime } });
  await firestoreCommit(env, writes, token);
  return json({ success: true, stockRestored: approve });
}

async function reviewRefund(request, env, uid, token) {
  await requireRole(env, uid, token, 'admin');
  const b = await request.json();
  const requestId = String(b.requestId || '').trim();
  const approve = b.approve === true;
  const ref = await firestoreGet(env, `refundRequests/${encodeURIComponent(requestId)}`, token);
  if (!ref || ref.data.status !== 'pending') throw Object.assign(new Error('Pending refund request not found.'), { status: 404 });
  const order = await firestoreGet(env, `orders/${encodeURIComponent(String(ref.data.orderId || ''))}`, token);
  if (!order || order.data.customerId !== ref.data.customerId) throw Object.assign(new Error('Refund order not found.'), { status: 404 });
  if (order.data.status !== 'delivered' || order.data.paymentStatus !== 'paid') {
    throw Object.assign(new Error('Refund approval requires a delivered, paid order.'), { status: 409 });
  }
  const now = new Date();
  const changes = { status: approve ? 'approved' : 'rejected', adminNote: String(b.adminNote || ''), reviewedBy: uid, reviewedAt: now,
    refundStatus: approve ? 'manual_refund_required' : 'not_approved' };
  const writes = [{ update: { name: documentName(env, `refundRequests/${encodeURIComponent(requestId)}`), fields: encodeFields(changes) }, updateMask: { fieldPaths: Object.keys(changes) }, currentDocument: { updateTime: ref.updateTime } }];
  if (approve) {
    const obligation = { requestId, orderId: String(ref.data.orderId), customerId: String(ref.data.customerId), amount: Number(order.data.customerTotal || 0), method: 'manual_admin_payment', status: 'due', createdAt: now };
    writes.push({ update: { name: documentName(env, `refund_obligations/${encodeURIComponent(requestId)}`), fields: encodeFields(obligation) }, currentDocument: { exists: false } });
  }
  await firestoreCommit(env, writes, token);
  return json({ success: true, refundStatus: approve ? 'manual_refund_required' : 'not_approved' });
}

async function markLedgerPaid(request, env, uid, token, collection) {
  await requireRole(env, uid, token, 'admin');
  const b = await request.json();
  const recordId = String(b.recordId || '').trim();
  const reference = String(b.paymentReference || '').trim();
  if (!recordId || reference.length < 3) throw Object.assign(new Error('Record ID and payment reference are required.'), { status: 400 });
  const path = `${collection}/${encodeURIComponent(recordId)}`;
  const record = await firestoreGet(env, path, token);
  if (!record) throw Object.assign(new Error('Payment record not found.'), { status: 404 });
  if (record.data.paid === true || record.data.status === 'paid') throw Object.assign(new Error('This record is already marked paid.'), { status: 409 });
  const now = new Date();
  await firestoreCommit(env, [{
    update: { name: documentName(env, path), fields: encodeFields({ paid: true, status: 'paid', paymentReference: reference, paidBy: uid, paidAt: now, updatedAt: now }) },
    updateMask: { fieldPaths: ['paid', 'status', 'paymentReference', 'paidBy', 'paidAt', 'updatedAt'] },
    currentDocument: { updateTime: record.updateTime },
  }], token);
  return json({ success: true });
}

async function markRefundObligationPaid(request, env, uid, token) {
  await requireRole(env, uid, token, 'admin');
  const b = await request.json();
  const recordId = String(b.recordId || '').trim();
  const reference = String(b.paymentReference || '').trim();
  if (!recordId || reference.length < 3) throw Object.assign(new Error('Refund record ID and payment reference are required.'), { status: 400 });
  const path = `refund_obligations/${encodeURIComponent(recordId)}`;
  const record = await firestoreGet(env, path, token);
  if (!record) throw Object.assign(new Error('Refund obligation not found.'), { status: 404 });
  if (record.data.status === 'paid') throw Object.assign(new Error('Refund is already marked paid.'), { status: 409 });
  const now = new Date();
  const writes = [{ update: { name: documentName(env, path), fields: encodeFields({ status: 'paid', paymentReference: reference, paidBy: uid, paidAt: now, updatedAt: now }) }, updateMask: { fieldPaths: ['status', 'paymentReference', 'paidBy', 'paidAt', 'updatedAt'] }, currentDocument: { updateTime: record.updateTime } }];
  const requestId = String(record.data.requestId || recordId);
  const refund = await firestoreGet(env, `refundRequests/${encodeURIComponent(requestId)}`, token);
  if (refund) writes.push({ update: { name: documentName(env, `refundRequests/${encodeURIComponent(requestId)}`), fields: encodeFields({ refundStatus: 'paid' }) }, updateMask: { fieldPaths: ['refundStatus'] }, currentDocument: { updateTime: refund.updateTime } });
  await firestoreCommit(env, writes, token);
  return json({ success: true });
}

async function markOrderPaid(request, env, uid, token) {
  await requireRole(env, uid, token, 'admin');
  const b = await request.json();
  const orderId = String(b.orderId || '').trim();
  const reference = String(b.transactionId || '').trim();
  if (!orderId || reference.length < 3) throw Object.assign(new Error('Order ID and manual payment reference are required.'), { status: 400 });
  const order = await firestoreGet(env, `orders/${encodeURIComponent(orderId)}`, token);
  if (!order || order.data.paymentMethod !== 'cod' || order.data.status !== 'delivered') throw Object.assign(new Error('Only delivered COD orders can be manually marked paid.'), { status: 409 });
  if (order.data.paymentStatus === 'paid') throw Object.assign(new Error('Order is already marked paid.'), { status: 409 });
  const now = new Date();
  const writes = [{ update: { name: documentName(env, `orders/${encodeURIComponent(orderId)}`), fields: encodeFields({ paymentStatus: 'paid', paymentConfirmationType: 'manual_admin', transactionId: reference, paymentUpdatedBy: uid, paymentUpdatedAt: now, updatedAt: now }) }, updateMask: { fieldPaths: ['paymentStatus', 'paymentConfirmationType', 'transactionId', 'paymentUpdatedBy', 'paymentUpdatedAt', 'updatedAt'] }, currentDocument: { updateTime: order.updateTime } }];
  const ledger = await firestoreGet(env, `platform_ledger/${encodeURIComponent(orderId)}`, token);
  if (ledger) writes.push({ update: { name: documentName(env, `platform_ledger/${encodeURIComponent(orderId)}`), fields: encodeFields({ paymentStatus: 'paid', paymentMethod: 'cod', transactionId: reference, paymentConfirmedAt: now }) }, updateMask: { fieldPaths: ['paymentStatus', 'paymentMethod', 'transactionId', 'paymentConfirmedAt'] }, currentDocument: { updateTime: ledger.updateTime } });
  await firestoreCommit(env, writes, token);
  return json({ success: true });
}

async function setDeliveryAvailability(request, env, uid, token) {
  await requireRole(env, uid, token, 'delivery');
  const b = await request.json();
  const available = b.available === true;
  const now = new Date();
  const user = await firestoreGet(env, `users/${encodeURIComponent(uid)}`, token);
  if (!user) throw Object.assign(new Error('Delivery profile missing.'), { status: 404 });
  if (available) {
    const assignedOrders = await firestoreList(env, 'orders', token, 1000);
    if (assignedOrders.some(x => x.data.deliveryBoyId === uid && !['delivered','cancelled','rejected','payment_failed'].includes(x.data.status))) {
      throw Object.assign(new Error('Active order complete hone ke baad hi dobara ONLINE ho sakte hain.'), { status: 409 });
    }
    const lat = Number(b.latitude), lon = Number(b.longitude);
    if (!Number.isFinite(lat) || lat < -90 || lat > 90 || !Number.isFinite(lon) || lon < -180 || lon > 180) {
      throw Object.assign(new Error('Online hone ke liye phone GPS location zaroori hai.'), { status: 400 });
    }
    if (user.data.deliveryOfferOrderId) throw Object.assign(new Error('Pehle current delivery offer accept/reject karein.'), { status: 409 });
    await saveDocument(env, `users/${encodeURIComponent(uid)}`, {
      deliveryAvailable: true, currentLocation: { latitude: lat, longitude: lon },
      lastLocationAt: now, updatedAt: now,
    }, token);
    // If a READY order was waiting for a rider, offer it as soon as this rider goes online.
    try {
      await processDeliveryOffers(env, token);
    } catch (dispatchError) {
      console.error('Dispatch on delivery worker online failed; cron will retry:', dispatchError);
    }
  } else {
    if (user.data.deliveryOfferOrderId) throw Object.assign(new Error('Active offer/order ke dauran offline nahi ho sakte.'), { status: 409 });
    await saveDocument(env, `users/${encodeURIComponent(uid)}`, { deliveryAvailable: false, updatedAt: now }, token);
  }
  return json({ success: true, deliveryAvailable: available });
}

async function updateDeliveryPresence(request, env, uid, token) {
  await requireRole(env, uid, token, 'delivery');
  const b = await request.json();
  const latitude = Number(b.latitude), longitude = Number(b.longitude);
  if (!Number.isFinite(latitude) || latitude < -90 || latitude > 90 || !Number.isFinite(longitude) || longitude < -180 || longitude > 180) {
    throw Object.assign(new Error('Invalid GPS coordinates.'), { status: 400 });
  }
  const user = await firestoreGet(env, `users/${encodeURIComponent(uid)}`, token);
  if (!user) throw Object.assign(new Error('Delivery profile missing.'), { status: 404 });
  await saveDocument(env, `users/${encodeURIComponent(uid)}`, {
    currentLocation: { latitude, longitude }, lastLocationAt: new Date(), updatedAt: new Date(),
  }, token);
  // Presence heartbeat can also wake up READY orders that were waiting for a nearby rider.
  try {
    await processDeliveryOffers(env, token);
  } catch (dispatchError) {
    console.error('Dispatch on delivery presence update failed; cron will retry:', dispatchError);
  }
  return json({ success: true });
}

async function respondDeliveryOffer(request, env, uid, token) {
  await requireRole(env, uid, token, 'delivery');
  const b = await request.json();
  const orderId = String(b.orderId || '');
  const accept = b.accept === true;
  const order = await firestoreGet(env, `orders/${encodeURIComponent(orderId)}`, token);
  const user = await firestoreGet(env, `users/${encodeURIComponent(uid)}`, token);
  if (!order || !user || order.data.deliveryOfferTo !== uid || user.data.deliveryOfferOrderId !== orderId) {
    throw Object.assign(new Error('Yeh delivery offer ab aapke liye available nahi hai.'), { status: 409 });
  }
  const now = new Date();
  const expiry = Date.parse(order.data.deliveryOfferExpiresAt || '');
  if (!Number.isFinite(expiry) || expiry <= now.getTime()) {
    await saveDocument(env, `users/${encodeURIComponent(uid)}`, { deliveryOfferOrderId: '', deliveryAvailable: true, updatedAt: now }, token);
    try { await processDeliveryOffers(env, token); } catch (dispatchError) { console.error('Expired-offer redispatch failed:', dispatchError); }
    throw Object.assign(new Error('60 second ka offer expire ho gaya. Agla offer system bhejega.'), { status: 409 });
  }
  if (accept) {
    await firestoreCommit(env, [
      { update: { name: documentName(env, `orders/${encodeURIComponent(orderId)}`), fields: encodeFields({ deliveryBoyId: uid, deliveryOfferTo: '', deliveryOfferExpiresAt: null, deliveryAssignmentStatus: 'assigned', deliveryAssignedAt: now, updatedAt: now }) }, updateMask: { fieldPaths: ['deliveryBoyId','deliveryOfferTo','deliveryOfferExpiresAt','deliveryAssignmentStatus','deliveryAssignedAt','updatedAt'] }, currentDocument: { updateTime: order.updateTime } },
      { update: { name: documentName(env, `users/${encodeURIComponent(uid)}`), fields: encodeFields({ deliveryOfferOrderId: '', deliveryAvailable: false, updatedAt: now }) }, updateMask: { fieldPaths: ['deliveryOfferOrderId','deliveryAvailable','updatedAt'] }, currentDocument: { updateTime: user.updateTime } },
    ], token);
    return json({ success: true, accepted: true, message: 'Order aapko assign ho gaya. Shop ready kare tab pickup karein.' });
  }
  const rejected = Array.isArray(order.data.deliveryRejectedIds) ? order.data.deliveryRejectedIds : [];
  await firestoreCommit(env, [
    { update: { name: documentName(env, `orders/${encodeURIComponent(orderId)}`), fields: encodeFields({ deliveryRejectedIds: [...new Set([...rejected, uid])], deliveryOfferTo: '', deliveryOfferExpiresAt: null, deliveryAssignmentStatus: 'searching', updatedAt: now }) }, updateMask: { fieldPaths: ['deliveryRejectedIds','deliveryOfferTo','deliveryOfferExpiresAt','deliveryAssignmentStatus','updatedAt'] }, currentDocument: { updateTime: order.updateTime } },
    { update: { name: documentName(env, `users/${encodeURIComponent(uid)}`), fields: encodeFields({ deliveryOfferOrderId: '', deliveryAvailable: true, updatedAt: now }) }, updateMask: { fieldPaths: ['deliveryOfferOrderId','deliveryAvailable','updatedAt'] }, currentDocument: { updateTime: user.updateTime } },
  ], token);
  try { await processDeliveryOffers(env, token); } catch (dispatchError) { console.error('Next-rider dispatch failed; cron will retry:', dispatchError); }
  return json({ success: true, accepted: false, message: 'Offer reject ho gaya. Agla delivery person search hoga.' });
}

async function processDeliveryOffers(env, token) {
  const [orders, users] = await Promise.all([
    firestoreList(env, 'orders', token, 1000),
    firestoreList(env, 'users', token, 1000),
  ]);
  const now = new Date();
  const lockedDeliveryIds = new Set();
  for (const entry of orders) {
    const o = entry.data;
    // Do not reserve a rider while the shop is still preparing the order.
    if (o.deliveryMode !== 'app' || o.status !== 'ready' || o.deliveryBoyId) continue;
    const location = o.customerLocation || {};
    const lat = Number(location.latitude), lon = Number(location.longitude);
    if (!Number.isFinite(lat) || !Number.isFinite(lon)) continue;
    const offerTo = String(o.deliveryOfferTo || '');
    const expires = Date.parse(o.deliveryOfferExpiresAt || '');
    if (offerTo && Number.isFinite(expires) && expires > now.getTime()) continue;
    const rejected = new Set(Array.isArray(o.deliveryRejectedIds) ? o.deliveryRejectedIds : []);
    if (offerTo) {
      rejected.add(offerTo);
      const expiredUser = await firestoreGet(env, `users/${encodeURIComponent(offerTo)}`, token);
      if (expiredUser && expiredUser.data.deliveryOfferOrderId === entry.id) {
        await saveDocument(env, `users/${encodeURIComponent(offerTo)}`, { deliveryOfferOrderId: '', deliveryAvailable: true, updatedAt: now }, token);
      }
    }
    const candidates = users.filter(u => {
      const d = u.data, loc = d.currentLocation || {};
      const last = Date.parse(d.lastLocationAt || '');
      return d.role === 'delivery' && d.approved === true && d.active !== false &&
        d.deliveryAvailable === true && !d.deliveryOfferOrderId && !lockedDeliveryIds.has(u.id) && !rejected.has(u.id) &&
        Number.isFinite(Number(loc.latitude)) && Number.isFinite(Number(loc.longitude)) &&
        Number.isFinite(last) && now.getTime() - last <= 5 * 60 * 1000;
    }).map(u => ({ ...u, distance: distanceKm(lat, lon, Number(u.data.currentLocation.latitude), Number(u.data.currentLocation.longitude)) }))
      .sort((a, b) => a.distance - b.distance);

    let chosen = null;
    let chosenFresh = null;
    for (const candidate of candidates) {
      const fresh = await firestoreGet(env, `users/${encodeURIComponent(candidate.id)}`, token);
      if (!fresh || fresh.data.role !== 'delivery' || fresh.data.approved !== true || fresh.data.active === false ||
          fresh.data.deliveryAvailable !== true || fresh.data.deliveryOfferOrderId) continue;
      const freshLast = Date.parse(fresh.data.lastLocationAt || '');
      if (!Number.isFinite(freshLast) || now.getTime() - freshLast > 5 * 60 * 1000) continue;
      if (rejected.has(candidate.id) || lockedDeliveryIds.has(candidate.id)) continue;
      chosen = candidate;
      chosenFresh = fresh;
      break;
    }
    if (!chosen || !chosenFresh) {
      if (offerTo || o.deliveryAssignmentStatus !== 'searching') {
        await saveDocument(env, `orders/${encodeURIComponent(entry.id)}`, { deliveryOfferTo: '', deliveryOfferExpiresAt: null, deliveryAssignmentStatus: 'searching', updatedAt: now }, token);
      }
      continue;
    }

    // Re-read the order and use Firestore update-time preconditions so two
    // simultaneous dispatch runs cannot reserve the same order twice.
    const freshOrder = await firestoreGet(env, `orders/${encodeURIComponent(entry.id)}`, token);
    if (!freshOrder || freshOrder.data.status !== 'ready' || freshOrder.data.deliveryMode !== 'app' || freshOrder.data.deliveryBoyId) continue;
    const activeOfferExpiry = Date.parse(freshOrder.data.deliveryOfferExpiresAt || '');
    if (freshOrder.data.deliveryOfferTo && Number.isFinite(activeOfferExpiry) && activeOfferExpiry > now.getTime()) continue;
    const freshRejected = new Set(Array.isArray(freshOrder.data.deliveryRejectedIds) ? freshOrder.data.deliveryRejectedIds : []);
    if (freshRejected.has(chosen.id)) continue;

    lockedDeliveryIds.add(chosen.id);
    const expiry = new Date(now.getTime() + 60 * 1000);
    await firestoreCommit(env, [
      { update: { name: documentName(env, `orders/${encodeURIComponent(entry.id)}`), fields: encodeFields({ deliveryOfferTo: chosen.id, deliveryOfferExpiresAt: expiry, deliveryAssignmentStatus: 'offered', deliveryOfferSentAt: now, updatedAt: now }) }, updateMask: { fieldPaths: ['deliveryOfferTo','deliveryOfferExpiresAt','deliveryAssignmentStatus','deliveryOfferSentAt','updatedAt'] }, currentDocument: { updateTime: freshOrder.updateTime } },
      { update: { name: documentName(env, `users/${encodeURIComponent(chosen.id)}`), fields: encodeFields({ deliveryAvailable: false, deliveryOfferOrderId: entry.id, updatedAt: now }) }, updateMask: { fieldPaths: ['deliveryAvailable','deliveryOfferOrderId','updatedAt'] }, currentDocument: { updateTime: chosenFresh.updateTime } },
    ], token);
  }
}

async function updateDeliveryLocation(request, env, uid, token) {
  await requireRole(env, uid, token, 'delivery');
  const b = await request.json();
  const orderId = String(b.orderId || '');
  const latitude = Number(b.latitude);
  const longitude = Number(b.longitude);

  if (!Number.isFinite(latitude) || latitude < -90 || latitude > 90 ||
      !Number.isFinite(longitude) || longitude < -180 || longitude > 180) {
    throw Object.assign(new Error('Invalid GPS coordinates.'), { status: 400 });
  }

  const order = await firestoreGet(env, `orders/${encodeURIComponent(orderId)}`, token);
  if (!order || order.data.deliveryBoyId !== uid ||
      !['ready', 'assigned', 'picked_up'].includes(order.data.status)) {
    throw Object.assign(new Error('Order is not assigned to you.'), { status: 403 });
  }

  await saveDocument(env, `orders/${encodeURIComponent(orderId)}`, {
    deliveryLocation: { latitude, longitude },
    deliveryLocationUpdatedAt: new Date(),
  }, token);

  return json({ success: true });
}

async function firestoreList(env, collectionPath, token, pageSize = 100) {
  const url = `${documentUrl(env, collectionPath)}?pageSize=${Math.min(Math.max(pageSize, 1), 1000)}`;
  const response = await fetch(url, { headers: { Authorization: `Bearer ${token}` } });
  const data = await response.json();
  if (!response.ok) {
    throw Object.assign(new Error(`Firestore list failed (${response.status}): ${data.error?.message || 'Unknown error'}`), { status: 502 });
  }
  return (data.documents || []).map(doc => ({
    id: doc.name.split('/').pop(),
    data: decodeFields(doc.fields || {}),
  }));
}

async function firestoreDelete(env, path, token) {
  const project = encodeURIComponent(env.FIREBASE_PROJECT_ID || '');
  const response = await fetch(
    `https://firestore.googleapis.com/v1/projects/${project}/databases/(default)/documents/${path}`,
    { method: 'DELETE', headers: { Authorization: `Bearer ${token}` } },
  );
  if (response.status === 404) return;
  if (!response.ok) {
    const data = await response.json().catch(() => ({}));
    throw Object.assign(new Error(`Firestore delete failed (${response.status}): ${data.error?.message || 'Unknown error'}`), { status: 502 });
  }
}

function validAdImageUrl(value) {
  try {
    const u = new URL(String(value || ''));
    return u.protocol === 'https:' && u.hostname.length > 0;
  } catch (_) { return false; }
}

// ADMIN: create a campaign for an approved shop.
async function adminCreateAd(request, env, uid, token) {
  await requireRole(env, uid, token, 'admin');
  const b = await request.json();
  const shopId = String(b.shopId || '').trim();
  const title = String(b.title || '').trim();
  const description = String(b.description || '').trim();
  const placement = String(b.placement || 'banner').trim();
  const packageDays = Number(b.packageDays);
  const imageUrl = String(b.imageUrl || '').trim();
  if (!shopId || title.length < 1 || title.length > 100 || description.length > 1000 ||
      ![7, 15, 30].includes(packageDays) || !['banner', 'shop_featured', 'product_featured', 'local_business'].includes(placement) || !validAdImageUrl(imageUrl)) {
    throw Object.assign(new Error('Invalid ad details. Check shop, title, description, package, placement and HTTPS image URL.'), { status: 400 });
  }
  const shopDoc = await firestoreGet(env, `shops/${encodeURIComponent(shopId)}`, token);
  const shop = shopDoc?.data;
  if (!shop || shop.approved !== true || shop.active !== true || !shop.ownerId) {
    throw Object.assign(new Error('Approved and active shop required.'), { status: 409 });
  }
  const campaignId = crypto.randomUUID();
  const now = new Date();
  const campaign = {
    ownerId: shop.ownerId, shopId, shopName: String(shop.name || ''),
    placement, packageDays, title, description, imageUrl,
    status: 'draft', paymentStatus: 'not_requested',
    impressionCount: 0, clickCount: 0,
    createdBy: uid, createdAt: now, updatedAt: now,
  };
  await saveDocument(env, `ad_campaigns/${campaignId}`, campaign, token, true);
  return json({ success: true, campaignId, message: 'Advertisement created by Admin.' });
}

// ADMIN: edit creative/placement/package while the campaign is not active.
async function adminUpdateAd(request, env, uid, token) {
  await requireRole(env, uid, token, 'admin');
  const b = await request.json();
  const campaignId = String(b.campaignId || '').trim();
  const old = await firestoreGet(env, `ad_campaigns/${encodeURIComponent(campaignId)}`, token);
  if (!old) throw Object.assign(new Error('Advertisement not found.'), { status: 404 });
  if (old.data.status !== 'draft') throw Object.assign(new Error('Only draft advertisements can be edited. Create a new draft or delete this campaign first.'), { status: 409 });
  const patch = {};
  if (b.title !== undefined) {
    const v = String(b.title).trim();
    if (!v || v.length > 100) throw Object.assign(new Error('Ad title must be 1-100 characters.'), { status: 400 });
    patch.title = v;
  }
  if (b.description !== undefined) {
    const v = String(b.description).trim();
    if (v.length > 1000) throw Object.assign(new Error('Description is too long.'), { status: 400 });
    patch.description = v;
  }
  if (b.imageUrl !== undefined) {
    const v = String(b.imageUrl).trim();
    if (!validAdImageUrl(v)) throw Object.assign(new Error('A valid HTTPS image URL is required.'), { status: 400 });
    patch.imageUrl = v;
  }
  if (b.placement !== undefined) {
    const v = String(b.placement);
    if (!['banner', 'shop_featured', 'product_featured', 'local_business'].includes(v)) throw Object.assign(new Error('विज्ञापन की जगह मान्य नहीं है।'), { status: 400 });
    patch.placement = v;
  }
  if (b.destinationUrl !== undefined) {
    const v = String(b.destinationUrl || '').trim();
    if (v && !validAdImageUrl(v)) throw Object.assign(new Error('A valid HTTPS destination URL is required.'), { status: 400 });
    patch.destinationUrl = v;
  }
  if (b.packageDays !== undefined) {
    const v = Number(b.packageDays);
    if (![7, 15, 30].includes(v)) throw Object.assign(new Error('Package must be 7, 15 or 30 days.'), { status: 400 });
    patch.packageDays = v;
  }
  if (!Object.keys(patch).length) throw Object.assign(new Error('No editable fields supplied.'), { status: 400 });
  patch.updatedAt = new Date();
  await saveDocument(env, `ad_campaigns/${encodeURIComponent(campaignId)}`, patch, token);
  return json({ success: true, message: 'Advertisement updated.' });
}

// ADMIN: configure advertisement package prices. Payments use the Paytm gateway.

async function adminGetAdSettings(request, env, uid, token) {
  await requireRole(env, uid, token, 'admin');
  const config = await firestoreGet(env, 'ad_settings/config', token);
  return json({ success: true, settings: config?.data || {} });
}

async function adminSaveAdSettings(request, env, uid, token) {
  await requireRole(env, uid, token, 'admin');
  const b = await request.json();
  const prices = b.packagePrices || {};
  const packagePrices = {};
  for (const days of [7, 15, 30]) {
    const amount = Number(prices[String(days)] ?? prices[days]);
    if (!Number.isFinite(amount) || amount <= 0 || amount > 10000000) {
      throw Object.assign(new Error(`Set a valid price for ${days} days.`), { status: 400 });
    }
    packagePrices[String(days)] = roundMoney(amount);
  }
  const current = await firestoreGet(env, 'ad_settings/config', token);
  const data = { packagePrices, updatedBy: uid, updatedAt: new Date() };
  const write = {
    update: { name: documentName(env, 'ad_settings/config'), fields: encodeFields(data) },
    updateMask: { fieldPaths: Object.keys(data) },
    currentDocument: current ? { updateTime: current.updateTime } : { exists: false },
  };
  await firestoreCommit(env, [write], token);
  return json({ success: true, message: 'Advertisement prices saved. Paytm gateway handles advertiser payments.' });
}

// SHOPKEEPER: read-only payment instructions. No ad_settings collection access is granted.
async function getAdPaymentInfo(request, env, uid, token) {
  const user = await firestoreGet(env, `users/${encodeURIComponent(uid)}`, token);
  if (!user || user.data.approved !== true || user.data.active === false || !['shopkeeper', 'customer'].includes(user.data.role)) throw Object.assign(new Error('सक्रिय दुकानदार लॉगिन जरूरी है।'), { status: 403 });
  const config = await firestoreGet(env, 'ad_settings/config', token);
  return json({ success: true, packagePrices: config?.data.packagePrices || {}, upiId: config?.data.upiId || '', qrImageUrl: config?.data.qrImageUrl || '' });
}

// ADMIN: quote the amount. Payment goes directly to the Admin UPI/bank account.
async function advertiserSubmitAdPayment(request, env, uid, token) {
  const user = await firestoreGet(env, `users/${encodeURIComponent(uid)}`, token);
  if (!user || user.data.approved !== true || user.data.active === false || user.data.role !== 'shopkeeper') throw Object.assign(new Error('सक्रिय दुकानदार लॉगिन जरूरी है।'), { status: 403 });
  const b = await request.json();
  const campaignId = String(b.campaignId || '').trim();
  const reference = String(b.paymentReference || '').trim();
  if (!campaignId || reference.length < 6 || reference.length > 120) throw Object.assign(new Error('सही UPI UTR / Transaction ID भरें।'), { status: 400 });
  const path = `ad_campaigns/${encodeURIComponent(campaignId)}`;
  const campaign = await firestoreGet(env, path, token);
  if (!campaign || campaign.data.ownerId !== uid) throw Object.assign(new Error('यह विज्ञापन आपके खाते का नहीं है।'), { status: 403 });
  if (campaign.data.status !== 'awaiting_payment' || campaign.data.paymentStatus !== 'pending') throw Object.assign(new Error('इस विज्ञापन के लिए अभी भुगतान स्वीकार नहीं हो रहा।'), { status: 409 });
  await saveDocument(env, path, { submittedPaymentReference: reference, paymentSubmittedAt: new Date(), updatedAt: new Date() }, token);
  return json({ success: true, message: 'UTR एडमिन को भेज दिया गया। भुगतान बैंक में जाँचने के बाद विज्ञापन चालू होगा।' });
}

async function advertiserCreateAdPayment(request, env, uid, token) {
  const user = await firestoreGet(env, `users/${encodeURIComponent(uid)}`, token);
  if (!user || user.data.approved !== true || user.data.active === false || !['shopkeeper', 'customer'].includes(user.data.role)) {
    throw Object.assign(new Error('सक्रिय अकाउंट से लॉगिन करें।'), { status: 403 });
  }
  const b = await request.json();
  const campaignId = String(b.campaignId || '').trim();
  if (!campaignId) throw Object.assign(new Error('विज्ञापन ID नहीं मिली।'), { status: 400 });
  const campaign = await firestoreGet(env, `ad_campaigns/${encodeURIComponent(campaignId)}`, token);
  if (!campaign || campaign.data.ownerId !== uid) throw Object.assign(new Error('यह विज्ञापन आपके खाते का नहीं है।'), { status: 403 });
  if (campaign.data.status !== 'awaiting_payment' || campaign.data.paymentStatus !== 'pending') {
    throw Object.assign(new Error('इस विज्ञापन का भुगतान अभी उपलब्ध नहीं है।'), { status: 409 });
  }
  const amount = roundMoney(Number(campaign.data.amount));
  if (!Number.isFinite(amount) || amount <= 0) throw Object.assign(new Error('विज्ञापन की राशि सही नहीं है।'), { status: 400 });
  paytmConfig(env);
  const sessionId = `AD${crypto.randomUUID().replace(/-/g, '')}`;
  await saveDocument(env, `payment_sessions/${encodeURIComponent(sessionId)}`, {
    customerId: uid, amount, paymentStatus: 'pending', gateway: 'paytm',
    paymentType: 'advertisement', campaignId, createdAt: new Date(), updatedAt: new Date(),
  }, token);
  return json({ success: true, sessionId, amount: amount.toFixed(2) });
}

async function adminQuoteAd(request, env, uid, token) {
  await requireRole(env, uid, token, 'admin');
  const b = await request.json();
  const campaignId = String(b.campaignId || '').trim();
  const amount = Number(b.amount);
  if (!Number.isFinite(amount) || amount <= 0) throw Object.assign(new Error('A valid amount is required.'), { status: 400 });
  const path = `ad_campaigns/${encodeURIComponent(campaignId)}`;
  const campaign = await firestoreGet(env, path, token);
  if (!campaign) throw Object.assign(new Error('Advertisement not found.'), { status: 404 });
  if (campaign.data.status === 'active') throw Object.assign(new Error('Pause the advertisement before changing its price.'), { status: 409 });
  if (['paid', 'verified'].includes(String(campaign.data.paymentStatus || '').toLowerCase())) throw Object.assign(new Error('This advertisement is already paid. Create a new campaign for another paid period.'), { status: 409 });
  await saveDocument(env, path, {
    amount: roundMoney(amount), status: 'awaiting_payment', paymentStatus: 'pending',
    quotedBy: uid, quotedAt: new Date(), updatedAt: new Date(),
  }, token);
  return json({ success: true, message: 'Payment amount sent to shopkeeper.' });
}

// ADMIN: manually verify the UTR in the Admin's bank/UPI app, then activate.
// This endpoint does NOT independently verify bank settlement; Admin must verify it externally.
async function adminVerifyAndActivateAd(request, env, uid, token) {
  await requireRole(env, uid, token, 'admin');
  const b = await request.json();
  const campaignId = String(b.campaignId || '').trim();
  const paymentReference = String(b.paymentReference || '').trim();
  const paidAmount = Number(b.paidAmount);
  const path = `ad_campaigns/${encodeURIComponent(campaignId)}`;
  const campaign = await firestoreGet(env, path, token);
  if (!campaign) throw Object.assign(new Error('Advertisement not found.'), { status: 404 });
  const c = campaign.data;
  if (c.status !== 'awaiting_payment' || c.paymentStatus !== 'pending') throw Object.assign(new Error('Advertisement is not awaiting payment.'), { status: 409 });
  if (paymentReference.length < 6 || !Number.isFinite(paidAmount) || paidAmount <= 0 || roundMoney(paidAmount) !== roundMoney(Number(c.amount))) {
    throw Object.assign(new Error('UTR/reference and exact quoted amount are required.'), { status: 400 });
  }
  const days = Number(c.packageDays);
  if (![7, 15, 30].includes(days)) throw Object.assign(new Error('Invalid campaign duration.'), { status: 409 });
  const now = new Date();
  await saveDocument(env, path, {
    paymentReference, paymentStatus: 'verified', paidAmount: roundMoney(paidAmount),
    status: 'active', startAt: now, endAt: new Date(now.getTime() + days * 86400000),
    verifiedBy: uid, verifiedAt: now, updatedAt: now,
  }, token);
  return json({ success: true, message: 'Payment marked verified and advertisement activated.' });
}

// ADMIN: reject, pause/resume, delete. All transitions are server-authorized.
async function adminChangeAdStatus(request, env, uid, token) {
  await requireRole(env, uid, token, 'admin');
  const b = await request.json();
  const campaignId = String(b.campaignId || '').trim();
  const action = String(b.action || '').trim();
  const path = `ad_campaigns/${encodeURIComponent(campaignId)}`;
  const campaign = await firestoreGet(env, path, token);
  if (!campaign) throw Object.assign(new Error('Advertisement not found.'), { status: 404 });
  if (action === 'delete') {
    if (['paid', 'verified'].includes(String(campaign.data.paymentStatus || '').toLowerCase()) || campaign.data.transactionId || campaign.data.paymentReference) {
      throw Object.assign(new Error('Paid advertisement records cannot be deleted. Pause the campaign to preserve its payment history.'), { status: 409 });
    }
    await firestoreDelete(env, path, token);
    return json({ success: true, message: 'Advertisement deleted.' });
  }
  if (action === 'pause') {
    await saveDocument(env, path, { status: 'paused', pausedBy: uid, pausedAt: new Date(), updatedAt: new Date() }, token);
  } else if (action === 'resume') {
    const end = Date.parse(campaign.data.endAt || '');
    if (campaign.data.paymentStatus !== 'verified' || !Number.isFinite(end) || end <= Date.now()) {
      throw Object.assign(new Error('Only a paid advertisement with remaining validity can be resumed.'), { status: 409 });
    }
    await saveDocument(env, path, { status: 'active', resumedBy: uid, resumedAt: new Date(), updatedAt: new Date() }, token);
  } else if (action === 'reject') {
    const reason = String(b.reason || '').trim();
    if (!reason || reason.length > 500) throw Object.assign(new Error('Rejection reason is required (maximum 500 characters).'), { status: 400 });
    await saveDocument(env, path, { status: 'rejected', paymentStatus: campaign.data.paymentStatus || 'not_requested', rejectionReason: reason, rejectedBy: uid, rejectedAt: new Date(), updatedAt: new Date() }, token);
  } else {
    throw Object.assign(new Error('Action must be pause, resume, reject or delete.'), { status: 400 });
  }
  return json({ success: true, message: `Advertisement action '${action}' completed.` });
}

// ADMIN: list every campaign; SHOPKEEPER: list only their own campaigns.
async function listAdCampaigns(request, env, uid, token, adminOnly = false) {
  const user = await firestoreGet(env, `users/${encodeURIComponent(uid)}`, token);
  if (!user || user.data.approved !== true || user.data.active === false || !['admin', 'shopkeeper', 'customer'].includes(user.data.role)) {
    throw Object.assign(new Error('Approved Admin or shopkeeper login required.'), { status: 403 });
  }
  if (adminOnly && user.data.role !== 'admin') throw Object.assign(new Error('Admin permission required.'), { status: 403 });
  const docs = await firestoreList(env, 'ad_campaigns', token, 1000);
  const campaigns = user.data.role === 'admin' ? docs : docs.filter(x => x.data.ownerId === uid);
  campaigns.sort((a, b) => String(b.data.createdAt || '').localeCompare(String(a.data.createdAt || '')));
  const safeCampaigns = campaigns.map(x => {
    if (user.data.role === 'admin') return { campaignId: x.id, ...x.data };
    const d = x.data;
    return { campaignId: x.id, title: d.title || '', shopName: d.shopName || '', placement: d.placement || '',
      packageDays: d.packageDays || 0, amount: d.amount ?? null, status: d.status || '',
      paymentStatus: d.paymentStatus || '', submittedPaymentReference: d.submittedPaymentReference || '', rejectionReason: d.rejectionReason || '',
      createdAt: d.createdAt || null, startAt: d.startAt || null, endAt: d.endAt || null };
  });
  return json({ success: true, campaigns: safeCampaigns });
}



// BACKEND-ONLY AD EVENT TRACKING: clients cannot write ad_events or counters directly.

async function getActiveAds(request, env, uid, token) {
  const docs = await firestoreList(env, 'ad_campaigns', token, 1000);
  const now = Date.now();
  const campaigns = docs.filter(x => {
    const d=x.data; const start=Date.parse(d.startAt || ''); const end=Date.parse(d.endAt || '');
    return d.status === 'active' && ['banner', 'shop_featured', 'product_featured', 'local_business'].includes(d.placement || 'banner') && Number.isFinite(start) && Number.isFinite(end) && now >= start && now < end;
  }).map(x => ({ campaignId:x.id, shopId:x.data.shopId || '', shopName:x.data.shopName || '', title:x.data.title || '', description:x.data.description || '', imageUrl:x.data.imageUrl || '', destinationUrl:x.data.destinationUrl || '', placement:x.data.placement || 'banner', packageDays:x.data.packageDays || 0 }));
  return json({ success:true, campaigns });
}


async function trackAdEvent(request, env, uid, token) {
  const body = await request.json();
  const campaignId = String(body.campaignId || '').trim();
  const eventType = String(body.eventType || '').trim();
  if (!/^[A-Za-z0-9_-]{1,120}$/.test(campaignId) || !['impression', 'click'].includes(eventType)) {
    throw Object.assign(new Error('Invalid advertisement event.'), { status: 400 });
  }
  const campaignDoc = await firestoreGet(env, `ad_campaigns/${encodeURIComponent(campaignId)}`, token);
  const campaign = campaignDoc?.data;
  const now = Date.now();
  const start = campaign?.startAt ? Date.parse(campaign.startAt) : NaN;
  const end = campaign?.endAt ? Date.parse(campaign.endAt) : NaN;
  if (!campaign || campaign.status !== 'active' || !Number.isFinite(start) || !Number.isFinite(end) || now < start || now >= end) {
    throw Object.assign(new Error('Advertisement is not currently active.'), { status: 404 });
  }
  if (campaign.ownerId === uid) return json({ success: true, counted: false, reason: 'owner_event_ignored' });
  const day = new Date().toISOString().slice(0, 10).replace(/-/g, '');
  const eventId = `${campaignId}_${uid}_${eventType}_${day}`.replace(/[^A-Za-z0-9_-]/g, '_').slice(0, 500);
  const eventPath = `ad_events/${encodeURIComponent(eventId)}`;
  const counterField = eventType === 'impression' ? 'impressionCount' : 'clickCount';
  const project = encodeURIComponent(env.FIREBASE_PROJECT_ID || '');
  const response = await fetch(`https://firestore.googleapis.com/v1/projects/${project}/databases/(default)/documents:commit`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ writes: [
      { update: { name: documentName(env, eventPath), fields: encodeFields({ campaignId, ownerId: campaign.ownerId || '', viewerUid: uid, eventType, eventDay: day, createdAt: new Date() }) }, currentDocument: { exists: false } },
      { transform: { document: documentName(env, `ad_campaigns/${encodeURIComponent(campaignId)}`), fieldTransforms: [{ fieldPath: counterField, increment: { integerValue: '1' } }] } },
    ] }),
  });
  const result = await response.json();
  if (!response.ok) {
    if (/ALREADY_EXISTS|FAILED_PRECONDITION/i.test(result.error?.status || '') || response.status === 409) {
      return json({ success: true, counted: false, reason: 'already_counted_today' });
    }
    throw Object.assign(new Error(`Advertisement event could not be saved (${response.status}).`), { status: 502 });
  }
  return json({ success: true, counted: true, eventType });
}



async function expireOldPaytmSessions(env, token) {
  const sessions = await firestoreList(env, 'payment_sessions', token, 1000);
  const now = new Date();
  for (const entry of sessions) {
    const session = entry.data;
    if (session.paymentStatus !== 'pending') continue;
    const created = Date.parse(session.createdAt || '');
    if (!Number.isFinite(created) || now.getTime() - created < 30 * 60 * 1000) continue;
    const latest = await firestoreGet(env, `payment_sessions/${encodeURIComponent(entry.id)}`, token);
    if (!latest || latest.data.paymentStatus !== 'pending') continue;
    const writes = [];
    for (const orderId of (Array.isArray(latest.data.orderIds) ? latest.data.orderIds : [])) {
      const order = await firestoreGet(env, `orders/${encodeURIComponent(orderId)}`, token);
      if (!order || order.data.paymentStatus === 'paid' || order.data.status !== 'pending_payment') continue;
      writes.push({ update: { name: documentName(env, `orders/${encodeURIComponent(orderId)}`), fields: encodeFields({ status: 'payment_failed', paymentStatus: 'failed', updatedAt: now }) }, updateMask: { fieldPaths: ['status','paymentStatus','updatedAt'] }, currentDocument: { updateTime: order.updateTime } });
      for (const item of (Array.isArray(order.data.items) ? order.data.items : [])) {
        const product = await firestoreGet(env, `products/${encodeURIComponent(String(item.productId || ''))}`, token);
        if (!product) continue;
        const stock = Number(product.data.stock || 0), qty = Number(item.quantity || 0);
        if (!Number.isInteger(qty) || qty < 1) continue;
        writes.push({ update: { name: documentName(env, `products/${encodeURIComponent(String(item.productId))}`), fields: encodeFields({ stock: stock + qty, active: true, updatedAt: now }) }, updateMask: { fieldPaths: ['stock','active','updatedAt'] }, currentDocument: { updateTime: product.updateTime } });
      }
    }
    writes.push({ update: { name: documentName(env, `payment_sessions/${encodeURIComponent(entry.id)}`), fields: encodeFields({ paymentStatus: 'expired', updatedAt: now }) }, updateMask: { fieldPaths: ['paymentStatus','updatedAt'] }, currentDocument: { updateTime: latest.updateTime } });
    if (latest.data.paymentType === 'shopkeeper_pro' && latest.data.subscriptionId) {
      const sub = await firestoreGet(env, `shopkeeper_subscriptions/${encodeURIComponent(latest.data.subscriptionId)}`, token);
      if (sub && sub.data.status === 'pending') writes.push({ update: { name: documentName(env, `shopkeeper_subscriptions/${encodeURIComponent(latest.data.subscriptionId)}`), fields: encodeFields({ status: 'expired', paymentStatus: 'expired', updatedAt: now }) }, updateMask: { fieldPaths: ['status','paymentStatus','updatedAt'] }, currentDocument: { updateTime: sub.updateTime } });
    }
    if (writes.length) await firestoreCommit(env, writes, token);
  }
}

export default {
  async fetch(request, env) {
    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: CORS_HEADERS });
    }

    const url = new URL(request.url);
    if (request.method === 'GET' && url.pathname === '/paytm/checkout') return paytmCheckoutPage(request, env);
    if (request.method === 'GET' && url.pathname === '/api/admob/ssv') return await processAdmobRewardSsv(request, env);
    if (request.method === 'GET' && url.pathname === '/health') {
      return json({
        success: true,
        message: 'Sanchore Bazaar API is running',
        project: env.FIREBASE_PROJECT_ID || null,
        serviceAccountConfigured: Boolean(env.FIREBASE_SERVICE_ACCOUNT_JSON),
        webApiKeyConfigured: Boolean(env.FIREBASE_WEB_API_KEY),
        emailOtpConfigured: Boolean(env.BYTELABS_MAIL_KEY && env.BYTELABS_FROM_EMAIL && env.OTP_HASH_SECRET),
        paytmConfigured: Boolean(env.PAYTM_MID && env.PAYTM_MERCHANT_KEY),
        cronRequired: true,
      });
    }

    if (request.method !== 'POST') {
      return json({ success: false, error: 'Method not allowed.' }, 405);
    }

    try {
      const uid = await authenticate(request, env);
      const token = await googleAccessToken(env);

      if (url.pathname === '/api/saveFeeSettings') return await saveFeeSettings(request, env, uid, token);
      if (url.pathname === '/api/admin/savePaymentSettings') return await adminSavePaymentSettings(request, env, uid, token);
      if (url.pathname === '/api/createOrder') return await createOrder(request, env, uid, token);
      if (url.pathname === '/api/registerCustomerProfile') return await registerCustomerProfile(request, env, uid, token);
      if (url.pathname === '/api/rewards/createSession') return await createRewardSession(request, env, uid, token);
      if (url.pathname === '/api/paytm/verify') return await paytmVerify(request, env, uid, token);
      if (url.pathname === '/api/paytm/initiate') return await paytmInitiate(request, env, uid, token);
      if (url.pathname === '/api/shopkeeper/proInfo') return await shopkeeperProInfo(request, env, uid, token);
      if (url.pathname === '/api/shopkeeper/createProPayment') return await shopkeeperCreateProPayment(request, env, uid, token);
      if (url.pathname === '/api/admin/shopkeeperProSettings') return await adminShopkeeperProSettings(request, env, uid, token);
      if (url.pathname === '/api/admin/saveShopkeeperProPrices') return await adminSaveShopkeeperProPrices(request, env, uid, token);
      if (url.pathname === '/api/admin/setShopkeeperProStatus') return await adminSetShopkeeperProStatus(request, env, uid, token);
      if (url.pathname === '/api/admin/grantShopkeeperPro') return await adminGrantShopkeeperPro(request, env, uid, token);
      if (url.pathname === '/api/applyStaffRegistration') return await applyStaffRegistration(request, env, uid, token);
      if (url.pathname === '/api/approveStaff') return await approveStaff(request, env, uid, token);
      if (url.pathname === '/api/checkServiceArea') return await checkServiceArea(request, env, uid, token);
      if (url.pathname === '/api/admin/listServiceAreas') return await adminListServiceAreas(request, env, uid, token);
      if (url.pathname === '/api/admin/addServiceArea') return await adminAddServiceArea(request, env, uid, token);
      if (url.pathname === '/api/admin/updateServiceArea') return await adminUpdateServiceArea(request, env, uid, token);
      if (url.pathname === '/api/admin/deleteServiceArea') return await adminDeleteServiceArea(request, env, uid, token);
      if (url.pathname === '/api/admin/setCodOverride') return await adminSetCodOverride(request, env, uid, token);
      if (url.pathname === '/api/admin/listCodAccounts') return await adminListCodAccounts(request, env, uid, token);
      if (url.pathname === '/api/admin/deactivateStaff') return await adminDeactivateStaff(request, env, uid, token);
      if (url.pathname === '/api/admin/reactivateStaff') return await adminReactivateStaff(request, env, uid, token);
      if (url.pathname === '/api/advertiser/requestAd') return await requestExternalAd(request, env, uid, token);
      if (url.pathname === '/api/advertiser/myAdRequests') return await advertiserMyAdRequests(request, env, uid, token);
      if (url.pathname === '/api/advertiser/submitAdPayment') return await advertiserSubmitAdPayment(request, env, uid, token);
      if (url.pathname === '/api/advertiser/createAdPayment') return await advertiserCreateAdPayment(request, env, uid, token);
      if (url.pathname === '/api/admin/listAdRequests') return await adminListAdRequests(request, env, uid, token);
      if (url.pathname === '/api/admin/rejectAdRequest') return await adminRejectAdRequest(request, env, uid, token);
      if (url.pathname === '/api/admin/generateAdCreative') return await adminGenerateAdCreative(request, env, uid, token);
      if (url.pathname === '/api/admin/createAdFromRequest') return await adminCreateAdFromRequest(request, env, uid, token);
      if (url.pathname === '/api/createShop') return await createShop(request, env, uid, token);
      if (url.pathname === '/api/shopkeeper/requestShopAddition') return await requestShopAddition(request, env, uid, token);
      if (url.pathname === '/api/admin/reviewShopRequest') return await reviewShopRequest(request, env, uid, token);
      if (url.pathname === '/api/approveShop') return await approveShop(request, env, uid, token);
      if (url.pathname === '/api/updateShop') return await updateShop(request, env, uid, token);
      if (url.pathname === '/api/deactivateShop') return await deactivateShop(request, env, uid, token);
      if (url.pathname === '/api/saveProduct') return await saveProduct(request, env, uid, token);
      if (url.pathname === '/api/deleteProduct') return await deleteProduct(request, env, uid, token);
      if (url.pathname === '/api/assignDelivery') return await assignDelivery(request, env, uid, token);
      if (url.pathname === '/api/updateStaffOrder') return await updateStaffOrder(request, env, uid, token);
      if (url.pathname === '/api/recordPurchase') return await recordPurchase(request, env, uid, token);
      if (url.pathname === '/api/updateShopSchedule') return await updateShopSchedule(request, env, uid, token);
      if (url.pathname === '/api/admin/reviewCancellation') return await reviewCancellation(request, env, uid, token);
      if (url.pathname === '/api/admin/reviewRefund') return await reviewRefund(request, env, uid, token);
      if (url.pathname === '/api/admin/markOrderPaid') return await markOrderPaid(request, env, uid, token);
      if (url.pathname === '/api/admin/markDeliveryEarningPaid') return await markLedgerPaid(request, env, uid, token, 'delivery_earnings');
      if (url.pathname === '/api/admin/markShopkeeperSettlementPaid') return await markLedgerPaid(request, env, uid, token, 'shopkeeper_settlements');
      if (url.pathname === '/api/admin/markRefundObligationPaid') return await markRefundObligationPaid(request, env, uid, token);
      if (url.pathname === '/api/updateDeliveryLocation') return await updateDeliveryLocation(request, env, uid, token);
      if (url.pathname === '/api/setDeliveryAvailability') return await setDeliveryAvailability(request, env, uid, token);
      if (url.pathname === '/api/updateDeliveryPresence') return await updateDeliveryPresence(request, env, uid, token);
      if (url.pathname === '/api/respondDeliveryOffer') return await respondDeliveryOffer(request, env, uid, token);
      if (url.pathname === '/api/admin/createAd') return await adminCreateAd(request, env, uid, token);
      if (url.pathname === '/api/admin/updateAd') return await adminUpdateAd(request, env, uid, token);
      if (url.pathname === '/api/admin/getAdSettings') return await adminGetAdSettings(request, env, uid, token);
      if (url.pathname === '/api/admin/saveAdSettings') return await adminSaveAdSettings(request, env, uid, token);
      if (url.pathname === '/api/shopkeeper/adPaymentInfo') return await getAdPaymentInfo(request, env, uid, token);
      if (url.pathname === '/api/admin/quoteAd') return await adminQuoteAd(request, env, uid, token);
      if (url.pathname === '/api/admin/verifyActivateAd') return await adminVerifyAndActivateAd(request, env, uid, token);
      if (url.pathname === '/api/admin/changeAdStatus') return await adminChangeAdStatus(request, env, uid, token);
      if (url.pathname === '/api/admin/listAds') return await listAdCampaigns(request, env, uid, token, true);
      if (url.pathname === '/api/shopkeeper/myAds') return await listAdCampaigns(request, env, uid, token, false);
      if (url.pathname === '/api/activeAds') return await getActiveAds(request, env, uid, token);
      if (url.pathname === '/api/trackAdEvent') return await trackAdEvent(request, env, uid, token);

      return json({ success: false, error: 'Endpoint not found.' }, 404);
    } catch (error) {
      const status = Number(error.status) || 400;
      return json({ success: false, error: error.message || 'Request failed.' }, status);
    }
  },
  async scheduled(event, env, ctx) {
    const token = await googleAccessToken(env);
    ctx.waitUntil(Promise.all([processDeliveryOffers(env, token), expireOldPaytmSessions(env, token)]));
  },
};
