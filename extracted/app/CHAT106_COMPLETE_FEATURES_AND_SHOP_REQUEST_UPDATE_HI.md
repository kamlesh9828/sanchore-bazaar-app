# Sanchore Bazaar – Chat 106 के फीचर और दुकान रिक्वेस्ट अपडेट

## इस अपडेट में नया

### दुकानदार की नई दुकान रिक्वेस्ट
- दुकानदार पैनल में **नई दुकान जोड़ने की रिक्वेस्ट भेजें** विकल्प।
- जानकारी: दुकान का नाम, श्रेणी, पूरा पता/क्षेत्र, मोबाइल नंबर, मालिक का नाम और वैकल्पिक फोटो URL।
- दुकानदार केवल रिक्वेस्ट भेज सकता है; वह सीधे `shops` में दुकान नहीं बना सकता। पुराना `/api/createShop` रास्ता अब मना करता है।
- एक दुकानदार की एक लंबित रिक्वेस्ट रहते दूसरी लंबित रिक्वेस्ट नहीं बनेगी।
- Admin की मंजूरी पर Worker नई दुकान बनाता है और उसे सक्रिय करता है।
- Admin रिजेक्ट करते समय कारण देना जरूरी है; दुकानदार अपने पैनल में स्थिति और कारण देख सकता है।
- `shop_requests` में client-side create/update/delete बंद है; सभी बदलाव Cloudflare Worker करता है।

### Admin Pro नियंत्रण
- सभी दुकानों की सदस्यता स्थिति सूची: Pro चालू, समाप्त/रोकी, Pro नहीं लिया, या दुकान अभी मंजूर/सक्रिय नहीं।
- पात्र (स्वीकृत और सक्रिय) दुकानों के लिए Pro दें या Renew/बढ़ाएँ।
- 30, 90, 180, 365 दिन; चालू Pro की अवधि मौजूदा expiry के बाद जुड़ती है।
- Admin सदस्यता रोक/बहाल कर सकता है।
- Admin द्वारा मुफ्त दी गई Pro सदस्यता `admin_granted` रिकॉर्ड है और Paytm Pro कमाई में शामिल नहीं होती।

## Chat 106 की पहले से मौजूद सुविधाएँ (प्रोजेक्ट में संरक्षित)
- Admin व्यवसाय/डिलीवरी रिपोर्ट: दुकानें, दुकानदार, डिलीवरी पार्टनर, डिलीवरी-तैयार और पूरे ऑर्डर का विवरण, दुकान के नाम सहित कम स्टॉक।
- दुकान और डिलीवरी पार्टनर को deactivate/reactivate करने की सुविधा; पुराने ऑर्डर/हिसाब सुरक्षित रहते हैं।
- अलग कमाई/लेजर: विज्ञापन भुगतान, ऑर्डर कमीशन, प्लेटफ़ॉर्म फीस, दुकानदार/डिलीवरी देनदारी और Pro भुगतान।
- विज्ञापन रिक्वेस्ट, Admin द्वारा अंतिम विज्ञापन बनाना/रिजेक्ट करना, sponsored shop/product, local business और home banner placements; 7/15/30 दिन के पैकेज।
- Shopkeeper Pro: ₹299/30 दिन और ₹2,999/365 दिन के शुरुआती Paytm plans; Admin कीमत बदल सकता है; Pro badge, shop-list priority, expiry/remaining days, Paytm verification और renewal।
- ऑर्डर/पेमेंट सफलता स्क्रीन और मौजूदा Cart, Orders, Ads, Points और Payment flows सुरक्षित रखने का उद्देश्य।

## तैनाती और परीक्षण
1. `cloudflare-worker/worker.js` को Cloudflare Worker `sanchore-bazaar-api` में पूरा replace करके Deploy करें।
2. `firestore.rules` को Firebase में Publish करें।
3. FlutLab में इस ZIP को import करके नया APK build करें।
4. वास्तविक Firebase/Paytm खाते से shop request, Admin approve/reject, Pro grant/renew, ads और order/payment flows टेस्ट करें।

Cloudflare Worker JavaScript syntax check किया गया। इस environment में Flutter/Dart SDK उपलब्ध नहीं था; इसलिए Flutter analyze/build और real-device/Paytm transaction test नहीं किया गया।
