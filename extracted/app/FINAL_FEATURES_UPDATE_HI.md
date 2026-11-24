# Sanchore Bazaar – फीचर जाँच और सुधार (Version 1.0.2+4)

## इस अपडेट में किए गए सुधार

1. **Admin डिलीवरी क्षेत्र स्क्रीन:** Admin अब डैशबोर्ड में क्षेत्र का नाम और 6 अंकों का PIN जोड़ सकता है, पुराने PIN/क्षेत्र देख सकता है, सक्रिय/बंद कर सकता है और हटा सकता है।
2. **PIN आधारित पता जाँच:** यदि Admin ने कम-से-कम एक PIN क्षेत्र जोड़ा है, तो ग्राहक का PIN सक्रिय सूची से मिलाया जाएगा। इस मोड में सेव पते को GPS coordinates के बिना भी चुना जा सकता है। पुराने radius क्षेत्र तब तक चलते रहेंगे जब तक PIN आधारित सेटअप शुरू नहीं किया जाता।
3. **सर्वर पर डिलीवरी जाँच:** Worker ऑर्डर बनाते समय PIN/radius दोबारा जाँचता है; केवल स्क्रीन की जाँच पर भरोसा नहीं करता।
4. **कूपन सुरक्षा:** सर्वर पर सक्रिय स्थिति, शुरू/समाप्ति समय, न्यूनतम ऑर्डर, प्रतिशत की अधिकतम 100 सीमा, fixed discount और maximum discount की जाँच मजबूत की गई। अंतिम छूट सर्वर ही निकालता है।
5. **Paytm असफलता और स्टॉक:** Paytm Initiate Transaction साफ तौर पर असफल हो या Paytm status API terminal failure लौटाए, तो pending order payment_failed होता है और आरक्षित स्टॉक एक atomic Firestore commit में लौटाया जाता है। Duplicate restore से बचने के लिए session/order update-time preconditions रखे गए हैं। Pending/अनिश्चित भुगतान पर स्टॉक तुरंत वापस नहीं किया जाता; 30 मिनट का expiry Cron reconciliation संभालता है।
6. **डिलीवरी ऑफर:** मौजूदा सिस्टम में 60 सेकंड का offer, accept/reject और अगले delivery partner की खोज मौजूद है। Cron हर मिनट चलने से वास्तविक अगला offer 60–120 सेकंड में जा सकता है।
7. **दुकानदार/ग्राहक/Admin:** मौजूदा registration, product/price/stock, order accept/reject, coupon, Admin approvals, ads, COD settings और order screens बरकरार हैं।

## अभी बाहरी खाते/जानकारी के कारण बाकी

- Paytm Live के लिए व्यापारी का वास्तविक MID, Merchant Key, Production approval और सफल live test जरूरी है। ऐप का कोड अकेले merchant activation नहीं कर सकता।
- Paytm Mobile App Verification का Play Store URL/प्रमाण Paytm Dashboard/Support से पूरा करना होगा। APK स्वीकार होगा या नहीं, यह Paytm की merchant verification policy और account review पर निर्भर है; इस ZIP से इसकी पुष्टि नहीं की जा सकती।
- Android Rewarded Video Ad Unit ID अब उपयोगकर्ता द्वारा पहले दी गई वास्तविक ID `ca-app-pub-6141339446909248/2536203308` से configure की गई है। RewardedAd लोड, दिखाने, reward callback, बंद होने पर dispose और अगला विज्ञापन preload करने की service जोड़ी गई है। Android App ID और Banner ID भी पहले से मौजूद हैं। iOS के लिए अलग Rewarded ID और App ID चाहिए।
- PIN आधारित डिलीवरी के लिए Admin को अपने वास्तविक सेवा क्षेत्र के 6-अंकीय PIN जोड़ने होंगे। कोई PIN अपने-आप अनुमान से नहीं जोड़ा गया।

## परीक्षण स्थिति

- Cloudflare Worker JavaScript syntax check चलाया जा सकता है; यह Flutter compile या Paytm live transaction का विकल्प नहीं है।
- इस वातावरण में Flutter/Dart SDK उपलब्ध नहीं है, इसलिए APK build, Firebase live test, Paytm live test और AdMob fill test सत्यापित नहीं किए गए। FlutLab में `Pub get` और Build चलाना जरूरी है।
