# Sanchore Bazaar v21 – सुधार और शेष सेटअप

## इस revision में source code के बदलाव
1. भारतीय फल, सब्जी और किराना नामों के लिए offline emoji catalog बना रखा है; अलग online image/emoji search हटाई गई है। UI और button styling नहीं बदली।
2. Rewarded Video के लिए one-use server session, AdMob signed Server-Side Verification, duplicate callback रोकना और server-side 1 point credit जोड़ा गया।
3. Customer Wallet screen में points balance और reward/redemption history जोड़ी गई। 100 points = ₹1।
4. Checkout में wallet points चुनकर redeem करने का विकल्प जोड़ा; Worker coupon के बाद उपलब्ध रकम, points balance और order creation को atomic commit में जाँचता है।
5. Customer और staff registration profile creation अब Worker से होता है; Worker Firebase account email को OTP verified email से मिलाता है। Firestore में client-side user profile creation बंद की गई।
6. Delivery offer केवल READY app-delivery order पर जाता है। Firestore update-time preconditions से concurrent duplicate reservation रोकी गई; reject/expiry के बाद अगला rider तुरंत खोजा जाता है।
7. Existing ads, Admin ads workflow, COD settings, checkout/payment, product, shop, order, delivery earnings और settlement flows बरकरार रखे गए।

## जरूरी बाहरी सेटअप (Build से पहले)
- `cloudflare-worker/worker.js` को existing Worker `sanchore-bazaar-api` पर deploy करें; पुराने Secrets/Variables न हटाएँ।
- Cloudflare में `ADMOB_REWARDED_AD_UNIT_ID=ca-app-pub-6141339446909248/2536203308` सेट करें।
- AdMob Rewarded Ad Unit में SSV callback URL `https://sanchore-bazaar-api.kamlesh9828-kp.workers.dev/api/admob/ssv` verify करके Save करें।
- `firestore.rules` Firebase Console में Publish करें।
- Delivery Cron `* * * * *` सक्रिय रखें।
- ByteLabs Worker variables/secrets सही हों और `/health` में `emailOtpConfigured: true` आए।

## सत्यापन स्थिति
- Cloudflare Worker JavaScript syntax check पास।
- AdMob SSV ECDSA DER signature conversion का generated-key self-test पास।
- Flutter/Dart SDK इस editing environment में उपलब्ध नहीं था; इसलिए `flutter analyze`, APK build और real-device test नहीं किए गए।
- वास्तविक Cloudflare deploy, AdMob Console SSV verification, Firestore Rules publish, ByteLabs email delivery, GPS dispatch और Paytm live payment account access के बिना यहाँ से नहीं किए जा सकते।
- Step-by-step सूची `BEFORE_BUILD_MANUAL_SETUP_HI.md` में है।
