# Sanchore Bazaar – Firebase Web सेटअप

V34 में Firebase Web की configuration `lib/firebase_options.dart` में पहले से जोड़ी गई है।

- Firebase Project ID: `sanchore-bazaar`
- Web App ID: `1:427408783867:web:f3d1ad4f2138573bbaf35e`
- Android ऐप अपनी मौजूदा `google-services.json` से इसी Firebase project को इस्तेमाल करता रहेगा।
- Web build को अब अलग `--dart-define` values की जरूरत नहीं है।

## FlutLab में क्या करें

1. V34 ZIP को नया project बनाकर import करें (पुराने V33 project को पहले सुरक्षित रखें)।
2. `pubspec.yaml` में Packages Get / Pub Get चलाएँ।
3. Web target उपलब्ध हो तो Web build चलाएँ।
4. Build सफल होने के बाद पहले preview URL पर login, products, cart और orders जाँचें।

## जरूरी Firebase Console सेटिंग

Firebase Console → Authentication → Settings → Authorized domains में अपनी website का domain
`sanchorebazaar.bg5.net` जोड़ें, यदि पहले से मौजूद न हो।

Authentication providers (जैसे Email/Password) और Firestore Rules भी सही enabled होने चाहिए।

## वेबसाइट के बारे में ضروری अंतर

इस ZIP में Flutter ऐप का Web version Firebase से connect किया गया है। आपकी मौजूदा Cloudflare Pages वाली अलग static website अपने-आप इस ZIP से नहीं बदलेगी। Android ऐप और इस Flutter Web build को एक ही Firebase project/Firestore इस्तेमाल कराने की configuration मौजूद है। मौजूदा static website को भी उसी database से जोड़ने के लिए उसके website source code में Firebase integration अलग से करना होगा या Flutter Web build को test करके website पर deploy करना होगा।

पहले preview पर पूरा परीक्षण करें; मौजूदा live website को बिना backup के overwrite न करें.
