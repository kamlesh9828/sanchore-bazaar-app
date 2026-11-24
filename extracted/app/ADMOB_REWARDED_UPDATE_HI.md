# AdMob Rewarded Video अपडेट

आपके पहले भेजे हुए असली Android IDs जोड़े/जाँचे गए हैं:

- AdMob Android App ID: `ca-app-pub-6141339446909248~2029595989`
- Banner Ad Unit ID: `ca-app-pub-6141339446909248/1441458533`
- Rewarded Video Ad Unit ID: `ca-app-pub-6141339446909248/2536203308`
- Interstitial Ad Unit ID (पहले से उपलब्ध): `ca-app-pub-6141339446909248/2811535478`
- App Open Ad Unit ID (पहले से उपलब्ध): `ca-app-pub-6141339446909248/2203875862`

Rewarded Ad ऐप शुरू होने पर preload होता है और केवल ग्राहक के स्पष्ट बटन दबाने पर चलता है। Client callback केवल स्क्रीन पर स्थिति दिखाता है; wallet में पॉइंट केवल Google के signed Server-Side Verification callback को Worker verify करने के बाद जुड़ते हैं। Ad खुलने या बंद होने पर कोई पॉइंट नहीं मिलता।

iOS के लिए अलग Rewarded Ad Unit ID और iOS App ID चाहिए।

AdMob खाते में ad unit active/approved और fill उपलब्ध होना भी जरूरी है। इस वातावरण में Flutter SDK नहीं है, इसलिए APK compile या live ad serving सत्यापित नहीं किया गया।


## नया सुरक्षित Reward Wallet सिस्टम
- ग्राहक वीडियो पूरा देखने पर 1 पॉइंट पाने के लिए opt-in बटन दबाता है।
- Rewarded Ad में Firebase UID और Worker से बना one-use session ID SSV custom data के रूप में सेट होते हैं।
- Cloudflare Worker Google के ECDSA signed SSV callback को verify करता है और duplicate transaction रोकता है। केवल सफल server verification पर 1 पॉइंट `users/{uid}.pointsBalance` में जुड़ता है।
- 100 पॉइंट = ₹1. Checkout में ग्राहक वॉलेट पॉइंट चुन सकता है; Worker उपलब्ध बैलेंस, कूपन के बाद की रकम और ऑर्डर को एक atomic commit में जाँचता/अपडेट करता है।
- ग्राहक My Wallet में बैलेंस और Reward History देख सकता है।

**AdMob Console में जरूरी सेटिंग:** Rewarded ad unit की Advanced settings → Server-side verification में callback URL `https://sanchore-bazaar-api.kamlesh9828-kp.workers.dev/api/admob/ssv` डालकर Verify और Save करें। Cloudflare Worker में `ADMOB_REWARDED_AD_UNIT_ID` को उसी ad unit ID पर सेट करें। नया `firestore.rules` Firebase Console में Publish करें।

इस source में Worker JavaScript syntax check किया जा सकता है, लेकिन Google का live SSV callback, Firestore deployment और Flutter build इस environment से नहीं चलाए गए हैं।


नए v25 में बिना query वाला URL health check जोड़ा गया है और Worker केवल reward_amount = 1 पर पॉइंट देता है। पूरी Deploy और AdMob Verify/Save प्रक्रिया `ADMOB_SSV_SETUP_STEP_BY_STEP_HI.md` में है।
