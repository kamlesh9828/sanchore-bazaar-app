# Sanchore Bazaar Cloudflare Worker

Deploy `worker.js` as the existing Sanchore Bazaar Worker.

## Required existing Firebase bindings
- `FIREBASE_PROJECT_ID` (Variable)
- `FIREBASE_WEB_API_KEY` (Variable)
- `FIREBASE_SERVICE_ACCOUNT_JSON` (Secret)

## Paytm settings
- `PAYTM_MID` (Variable)
- `PAYTM_MERCHANT_KEY` (Secret; never expose to the Flutter app)
- `PAYTM_ENV=STAGING` for tests or `PRODUCTION` after Paytm activation
- `PAYTM_WEBSITE_NAME=WEBSTAGING` for staging or `DEFAULT` for production
- `WORKER_PUBLIC_URL=https://sanchore-bazaar-api.kamlesh9828-kp.workers.dev`

Paytm uses server-side Initiate Transaction and server-side Transaction Status verification. The app never marks a payment paid based only on a client callback.

## Cron Trigger
Add `* * * * *` under Cloudflare Dashboard > Worker > Settings > Triggers > Cron Triggers. This runs nearest-delivery offer assignment and expires unpaid Paytm sessions. `wrangler.toml` contains the same trigger for Wrangler deployments.

## Registration OTP enforcement
- Customer profile creation and staff applications are accepted by the Worker only after the same Firebase account email has a verified OTP from the previous 30 minutes.
- Client-side direct creation of `/users/{uid}` is disabled in `firestore.rules`; publish the updated rules.

## Reward Wallet / AdMob SSV
- Set `ADMOB_REWARDED_AD_UNIT_ID` to the exact rewarded ad unit ID configured in AdMob (Android default in this app: `ca-app-pub-6141339446909248/2536203308`).
- In AdMob → Apps → Sanchore Bazaar → Rewarded ad unit → Advanced settings → Server-side verification, set callback URL to `https://sanchore-bazaar-api.kamlesh9828-kp.workers.dev/api/admob/ssv` and verify/save it.
- The app creates a one-use reward session and passes its ID as SSV custom data. The Worker verifies Google's ECDSA signature, checks the one-use session and credits exactly 1 point once per transaction. Client callbacks never write wallet points.
- Publish the updated `firestore.rules` so users can read only their own reward transaction history; all wallet writes remain Worker-only.
- Conversion: 100 points = ₹1. Checkout applies available points after coupon discount and deducts them atomically with order creation.

## ByteLabs Email OTP
- `BYTELABS_MAIL_KEY` (Secret)
- `BYTELABS_FROM_EMAIL` (Variable; set exactly to `noreply@sanchorebazaar.bg5.net` after verifying this sender in ByteLabs)
- `OTP_HASH_SECRET` (Secret; existing OTP hashing secret)

The worker sends registration OTP messages through ByteLabs Email API. Keep the API key out of Flutter/mobile code. See `BYTELABS_EMAIL_OTP_SETUP_HI.md`.
