# Sanchore Bazaar Login Update

## बदलाव
- ग्राहक Email/Password registration में registration OTP request/verify call हटा दी गई है।
- Forgot Password के लिए Firebase `sendPasswordResetEmail` ही email भेजता है।
- Login screen में Google और Apple provider विकल्प जोड़े गए हैं।
- Google/Apple से पहली बार login करने पर नाम और 10 अंकों का मोबाइल लेकर Cloudflare Worker के सुरक्षित `/api/registerCustomerProfile` से profile बनती है।
- Worker अब profile creation और staff application में OTP document की जाँच नहीं करता; Firebase ID token और Firebase Identity Toolkit account lookup से UID/email मिलान करता है। OTP endpoints की public routing बंद है।
- Firestore security rules बदले नहीं गए।

## Firebase Console में आवश्यक सेटअप
1. Authentication → Sign-in method → Google को Enable करें।
2. Authentication → Sign-in method → Apple को Enable करें। Apple के लिए Apple Developer में Services ID, Team ID, Key ID और private key की configuration भी जरूरी है।
3. Authentication → Settings → Authorized domains में `sanchorebazaar.bg5.net` और `sanchore-bazaar.firebaseapp.com` मौजूद रखें।
4. Cloudflare Worker में `FIREBASE_WEB_API_KEY` secret वही Firebase Web API key होना चाहिए।
5. Android Google sign-in के लिए Firebase Android app में SHA-1 और SHA-256 fingerprints जोड़कर नया `google-services.json` डाउनलोड करें।
6. Website deploy करने पर `website/index.html` को Pages की deployed root `index.html` के रूप में रखें।
7. Worker deploy करें: `cloudflare-worker/worker.js`।

## ध्यान दें
- Existing Firebase UID और existing Firestore profiles जस के तस रहते हैं। Google/Apple account तभी पुराने खाते से जुड़ता है जब Firebase Auth provider linking/एक ही email के account linking की अनुमति देता है; अलग provider से duplicate UID अपने-आप merge नहीं होते।
- इस environment में Flutter SDK उपलब्ध नहीं था, इसलिए APK build / `flutter analyze` नहीं चलाया गया। Firebase Console provider setup और Cloudflare deployment अभी करना बाकी है।
