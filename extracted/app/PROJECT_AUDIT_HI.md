# Sanchore Bazaar V35.1 — Project Audit

## Is release mein kiye gaye code fixes
- `lib/main.dart`: Admin AppBar title ke `const Row` ko non-const `Row` kiya, kyunki uske andar `InkWell` ka callback runtime expression hai.
- `lib/screens/order_success_screen.dart`: Widget tree ko dobara saaf, balanced aur formatted structure mein likha; purane extra closing brackets hata diye.
- `cloudflare-worker/worker.js`: Registration profile ke liye email ko Firebase ID token se authenticate karne wale helper ka naam clear kiya. Custom profile field `emailVerified` ko `false` rakha, kyunki is project mein registration email verification/OTP nahi bhejna hai.
- Root `.gitignore` add ki.

## Source/configuration audit
- Android package: `com.sanchorebazaar.app`.
- Firebase Android app config (`android/app/google-services.json`) maujood hai aur package name match karta hai.
- Firebase web config (`lib/firebase_options.dart`) maujood hai.
- Website `website/index.html` maujood hai.
- Cloudflare Worker `cloudflare-worker/worker.js` aur `wrangler.toml` maujood hain.
- Firestore rules file maujood hai; is update mein rules ko loose nahi kiya.

## Abhi bhi external setup zaroori hai
- Firebase Console mein Google provider enabled hai, lekin archive ke `google-services.json` mein OAuth client entries khaali hain. Firebase Project Settings se SHA-1/SHA-256 add karne ke baad naya `google-services.json` download karke replace karna hoga.
- Android Manifest mein Google Maps API key placeholder `YOUR_GOOGLE_MAPS_API_KEY` hai. Maps feature chalane ke liye restricted Android Maps SDK key chahiye.
- Firebase Web API key pehle `auth/api-key-not-valid` error de chuki hai. Is project mein wahi key maujood hai; isko Firebase/Google Cloud Console mein verify karna hoga. Worker secret `FIREBASE_WEB_API_KEY` bhi isi project ki valid Web API key se match hona chahiye.
- Apple Sign-In ke liye Apple Developer Services ID, Team ID, Key ID aur private key configuration abhi bhi chahiye.
- Website ka cart/checkout UI abhi khud page par batata hai ki live checkout API integrate nahi hai; isliye website ko complete live ordering system samajhkar deploy na karein.

## Build / lockfile status
- Is editing environment mein Flutter/Dart SDK available nahi tha. Isliye `flutter analyze`, `flutter test`, `flutter pub get` aur Android release APK build execute nahi ho sake.
- `pubspec.lock` source archive mein nahi tha. Is file ko manually fake nahi kiya gaya. FlutLab mein project kholkar `flutter pub get` / package get chalane par is dependency set ke liye sahi lockfile generate hoga.
- Cloudflare Worker JavaScript syntax check aur website inline JavaScript syntax check pass hue.

## FlutLab mein import karne ke baad
1. Project ZIP extract/import karein.
2. Packages / Pub get chalayein taaki `pubspec.lock` bane.
3. Firebase Console se SHA fingerprints register karke updated `google-services.json` replace karein.
4. Pehle Android APK build karein; agar error aaye to poora log share karein.
