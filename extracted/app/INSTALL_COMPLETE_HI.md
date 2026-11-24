# Sanchore Bazaar – पता, PIN Code और Checkout सुधार

- Checkout में नाम, मोबाइल, मकान/फ्लैट, सड़क, मोहल्ला, लैंडमार्क, गाँव/शहर, जिला, राज्य और 6 अंकों का PIN Code।
- GPS से उपलब्ध पता भरने की कोशिश; ग्राहक coordinates नहीं भरता।
- सेव किए हुए पते Checkout में चुन सकते हैं।
- My Account में अनेक Home/Office/Other पते, नाम, मोबाइल और लैंडमार्क सहित सेव होते हैं।
- Admin > Promotions & Service Areas में PIN जोड़ना, चालू/बंद करना और हटाना।
- Worker active PIN allow-list को server-side जाँचता है। PIN entries उपलब्ध हों तो GPS coordinates अनिवार्य नहीं; सही active PIN अनिवार्य है।

## FlutLab में लगाना
1. ZIP Extract करें।
2. `lib/` की फाइलें उसी path पर Replace करें।
3. `pubspec.yaml` से `flutter pub get` चलाएँ।
4. `cloudflare-worker/worker.js` Cloudflare पर Deploy करें।
5. `firestore.rules` Firebase Console में Publish करें।
6. Admin > Promotions & Service Areas में अपने सही PIN Codes जोड़ें।

## सीमाएँ
- यह source ZIP है, APK नहीं। Flutter SDK उपलब्ध न होने से Flutter analyze/APK build नहीं चला।
- GPS reverse-geocoding नेटवर्क/OpenStreetMap सेवा पर निर्भर है; विफल होने पर पता manually editable है।
- Paytm live के लिए व्यापारी द्वारा जारी PAYTM_MID, PAYTM_MERCHANT_KEY (Secret), PAYTM_ENV और सक्रिय merchant account चाहिए।


## नए चार चरणों के अपडेट
1. ग्राहक ऑर्डर ट्रैकिंग में स्थिति के चरण, दुकान द्वारा सेट किया गया अनुमानित समय और डिलीवरी पार्टनर का लाइव मैप दिखेगा।
2. Admin > Promotions & Service Areas में कूपन कोड, प्रतिशत/फिक्स छूट, न्यूनतम ऑर्डर और अधिकतम छूट सेट करें। Checkout पर ग्राहक कूपन लगा सकेगा। Worker सर्वर पर कूपन की दोबारा जाँच करके ही छूट लगाएगा।
3. ग्राहक Delivered ऑर्डर में “फिर से ऑर्डर करें” से पुराने सामान को Cart में डाल सकता है; Checkout पर वर्तमान स्टॉक/कीमत फिर से जाँची जाएगी।
4. दुकानदार > Dukaan Tools में अपनी दुकान का अनुमानित डिलीवरी समय 5 से 240 मिनट तक सेट कर सकता है। Admin Operations, स्टॉक अलर्ट, रिपोर्ट, रिफंड, कैंसिलेशन और सहायता स्क्रीन पहले से उपलब्ध मॉड्यूल के साथ रखे गए हैं।

### जरूरी सेटअप
- `cloudflare-worker/worker.js` को Cloudflare Worker में दोबारा Deploy करें।
- Android लाइव मैप के लिए Google Cloud Console में Maps SDK for Android चालू करके API key बनाएं और `android/app/src/main/AndroidManifest.xml` में `YOUR_GOOGLE_MAPS_API_KEY` बदलें। API key को Android package/SHA restrictions से सुरक्षित रखें।
- Admin स्क्रीन से कूपन बनाएं। कूपन का code 3–30 अक्षरों/अंकों का होना चाहिए।
- दुकानदार को Dukaan Tools में delivery estimate सेट करना होगा; नहीं तो ग्राहक को बताया जाएगा कि दुकान ने समय अपडेट नहीं किया।
- इस ZIP का Flutter APK अभी build/analyze नहीं किया गया है; FlutLab में `flutter pub get` करके build और वास्तविक device test जरूरी है।
