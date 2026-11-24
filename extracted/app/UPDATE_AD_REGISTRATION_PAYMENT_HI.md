# Sanchore Bazaar – दुकान पंजीकरण और विज्ञापन भुगतान अपडेट

## बदलाव
- Shopkeeper Panel से दुकान पंजीकरण फॉर्म और बटन हटाया गया। दुकान जोड़ने/स्वीकृति का प्रशासनिक प्रवाह और लॉगिन स्क्रीन का आवेदन लिंक यथावत है।
- Admin विज्ञापन सेटिंग में अब केवल 7, 15 और 30 दिन के पैकेज शुल्क रखे गए हैं; UPI ID/QR भरने की जरूरत नहीं।
- दुकानदार या बाहरी विज्ञापनदाता के लिए Admin द्वारा विज्ञापन स्वीकृत और शुल्क तय करने के बाद Pay Now बटन आता है।
- Pay Now सुरक्षित Paytm Checkout शुरू करता है। वहाँ Merchant खाते में सक्षम UPI ऐप/QR, कार्ड और नेट बैंकिंग विकल्प Paytm द्वारा दिखाए जाते हैं।
- भुगतान केवल Paytm server-side status और checksum जाँच सफल होने पर विज्ञापन को paid/active करता है।

## जरूरी तैनाती
1. `cloudflare-worker/worker.js` को उसी Cloudflare Worker में Deploy करें।
2. Worker में पहले से कॉन्फ़िगर `PAYTM_MID`, encrypted `PAYTM_MERCHANT_KEY`, `PAYTM_ENV`, `PAYTM_WEBSITE_NAME` और `WORKER_PUBLIC_URL` ज्यों के त्यों रखें। Merchant Key को Flutter ऐप में न डालें।
3. Paytm Merchant खाते में UPI/QR, कार्ड, नेट बैंकिंग और UPI Intent के जो विकल्प सक्रिय हैं, वही Checkout में उपलब्ध होंगे।
4. FlutLab में ZIP की फाइलें अपडेट करके Pub get और Build चलाएँ।

## जाँच सीमा
Worker JavaScript syntax check सफल। इस वातावरण में Flutter/Dart SDK उपलब्ध नहीं था, इसलिए Flutter compile/APK build और असली Paytm लेन-देन का परीक्षण नहीं किया गया। पहले Paytm staging में सफल, असफल और cancel भुगतान जाँचें।
