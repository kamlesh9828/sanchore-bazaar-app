# Sanchore Bazaar – Build से पहले जरूरी सेटअप

इस source update में Reward Wallet, AdMob SSV verification, OTP profile security और READY-only delivery dispatch के बदलाव जोड़े गए हैं। Build अभी नहीं किया गया है। Live app चलाने से पहले नीचे के server/account steps जरूरी हैं।

## 1. Cloudflare Worker deploy
1. Cloudflare Dashboard → Workers & Pages → `sanchore-bazaar-api` खोलें।
2. इस ZIP के `cloudflare-worker/worker.js` का पूरा नया code deploy करें।
3. पुराने Secrets/Variables को delete या replace न करें।
4. Plain variable जोड़ें: `ADMOB_REWARDED_AD_UNIT_ID` = `ca-app-pub-6141339446909248/2536203308`.
5. Worker का `/health` खोलकर `serviceAccountConfigured`, `emailOtpConfigured` और `paytmConfigured` जाँचें।

## 2. AdMob में Server-Side Verification
1. AdMob → Apps → Sanchore Bazaar → Rewarded ad unit खोलें।
2. Advanced settings → Server-side verification में जाएँ।
3. Callback URL डालें:
   `https://sanchore-bazaar-api.kamlesh9828-kp.workers.dev/api/admob/ssv`
4. Verify URL दबाएँ, फिर Use verified URL और Save करें।
5. ऐप में ग्राहक खुद वीडियो चलाएगा। Google का signed callback सही होने पर ही Worker 1 पॉइंट देगा।

## 3. Firebase Firestore Rules publish
1. Firebase Console → Firestore Database → Rules खोलें।
2. ZIP का `firestore.rules` पूरा replace करके Publish करें।
3. इससे customer/staff profile creation Worker से OTP जाँचकर होगा; reward balance और reward history client से बदली नहीं जा सकेगी।

## 4. Delivery Cron
Cloudflare Worker → Settings → Triggers → Cron Triggers में `* * * * *` सक्रिय रखें। READY ऑर्डर पर तत्काल offer भी भेजा जाता है; Cron expired offer और retry के लिए fallback है।

## 5. ByteLabs Email OTP
Worker में पहले से उपयोग किए जा रहे ये values मौजूद और सही होने चाहिए:
- Secret: `BYTELABS_MAIL_KEY`
- Secret: `OTP_HASH_SECRET`
- Variable: `BYTELABS_FROM_EMAIL`

API key केवल Cloudflare Secret में रखें, Flutter source या chat में नहीं। `/health` में `emailOtpConfigured: true` आना चाहिए।

## 6. Live test checklist (Build के बाद)
- नए customer email पर OTP आए; गलत/expired OTP से registration न हो।
- Shopkeeper और delivery registration भी OTP के बिना profile न बनाए।
- Customer एक Rewarded Video पूरा करे; SSV verification के बाद wallet में ठीक 1 point जुड़े।
- उसी SSV callback को दोबारा भेजने पर दूसरा point न जुड़े।
- 100 पॉइंट = ₹1 की दर से छूट दिखे; एक ऑर्डर में छूट सामान के कुल मूल्य की अधिकतम 25% हो; इस्तेमाल हुए पॉइंट balance से घटें और इतिहास में दिखें।
- भुगतान हो चुके विज्ञापन कैंपेन को हटाने/उसी कैंपेन पर दोबारा शुल्क लगाने की कोशिश अस्वीकार हो।
- Admin की "मेरी कमाई और भुगतान" रिपोर्ट में विज्ञापन भुगतान, कमीशन, प्लेटफ़ॉर्म शुल्क और दुकानदार/डिलीवरी की बाकी देनदारी अलग-अलग दिखे।
- Shopkeeper order READY करे; nearest fresh-GPS approved online rider को 60-second offer मिले। Preparing status पर offer न मिले। Reject/expiry पर अगला rider खोजा जाए।
- Banner, interstitial और App Open ads approved/fill के साथ दिखें; checkout/payment के बीच interstitial न आए।

## v22 अतिरिक्त जाँच
- Rewarded Ads से मिले पॉइंट उसी ग्राहक के खाते में रहें; उन्हें नकद या दूसरे खाते में ट्रांसफर न किया जा सके।
- Rewarded Ad छूट 25% की सर्वर सीमा से अधिक न हो, चाहे ग्राहक modified app से अधिक पॉइंट भेजे।
- विज्ञापनदाता Paytm भुगतान केवल आपके अपने `PAYTM_MID` वाले स्वीकृत Merchant खाते में जाए।

## अभी क्या verify नहीं हुआ
- इस environment में Flutter/Dart SDK उपलब्ध नहीं था, इसलिए `flutter analyze`, APK build और device test नहीं किए गए।
- Worker JavaScript syntax check और AdMob SSV ECDSA signature-conversion self-test पास हुए। वास्तविक Cloudflare deploy, AdMob Console verification, Firebase Rules publish, ByteLabs delivery और live GPS/payment tests account access के बिना यहाँ से नहीं किए जा सकते।
