# Sanchore Bazaar v30 – Chat 106 संयुक्त अपडेट

## इस वर्जन में नया
- दुकानदार पैनल से नई दुकान जोड़ने की रिक्वेस्ट भेज सकता है; वह खुद दुकान नहीं बना सकता।
- दुकान रिक्वेस्ट में नाम, श्रेणी, पता, मोबाइल, मालिक का नाम और वैकल्पिक फोटो URL लिया जाता है।
- Admin पैनल में अलग लंबित दुकान रिक्वेस्ट सूची; Admin ही Approve/Reject कर सकता है।
- Reject करते समय कारण अनिवार्य; दुकानदार अपने पैनल में कारण और स्थिति देखता है।
- दुकान का वास्तविक रिकॉर्ड Admin approval के बाद ही Worker बनाता है। पुराने direct-create API को बंद किया गया।
- Admin Pro सूची में Pro चालू, समाप्त/रोकी और Pro नहीं लेने वाली दुकानों की गिनती; हर दुकान की अवधि/expiry/बाकी दिन और Renew/बढ़ाएँ कार्रवाई।

## Chat 106 से सुरक्षित/शामिल मौजूदा सुविधाएँ
- Admin व्यवसाय और डिलीवरी रिपोर्ट: दुकानें, दुकानदार, डिलीवरी पार्टनर, delivery-ready orders, delivered orders के विवरण और दुकान के अनुसार low-stock.
- दुकानदार/डिलीवरी खातों को बंद/दोबारा चालू करना; पुराने orders और ledger रिकॉर्ड सुरक्षित रखना।
- Admin revenue: विज्ञापन भुगतान, order commission, platform fee, shopkeeper/delivery payable amounts और Pro payments अलग।
- Ad request और Admin Ad Studio: Admin final creative, price, package, approval और activation नियंत्रित करता है; sponsored shop/product, local business, home banner placements; 7/15/30 दिन।
- Shopkeeper Pro paid plans: शुरुआती ₹299/30 दिन, ₹2,999/365 दिन; Admin price control; Paytm verification; Pro badge, shop-list priority, expiry/remaining days; renewal.
- Admin manual Pro grant/extend/stop/restore: 30/90/180/365 दिन; manual grant को Paytm income नहीं गिना जाता।
- Order success animation और payment status confirmation screen।
- मौजूदा Cart, Orders, Ads, Reward Points और Payment flows को संरक्षित रखा गया है।

## जरूरी तैनाती
1. इस ZIP से Flutter/FlutLab प्रोजेक्ट अपडेट करें और नया APK build करें।
2. `cloudflare-worker/worker.js` को Cloudflare Worker `sanchore-bazaar-api` में पूरा replace करके Deploy करें।
3. `firestore.rules` को Firebase में Publish करें।
4. दुकान रिक्वेस्ट, Admin approve/reject, Pro grant/renew, विज्ञापन भुगतान और ग्राहक order/payment को वास्तविक खाते से टेस्ट करें।

## जाँच की सीमा
Cloudflare Worker JavaScript syntax check पास। ZIP integrity check पास। इस वातावरण में Flutter/Dart SDK उपलब्ध नहीं था; इसलिए Flutter analyze/build और वास्तविक मोबाइल/Paytm transaction परीक्षण नहीं किया गया।
- ग्राहक पक्ष में persistent cart, पसंदीदा दुकान/सामान, ऑर्डर इतिहास/विवरण, फिर से ऑर्डर, ऑर्डर ट्रैकिंग/डिलीवरी लोकेशन, इन-ऐप सूचनाएँ और cancellation/refund request status के मौजूदा मॉड्यूल सुरक्षित हैं।
- दुकानदार के लिए कम स्टॉक मॉनिटरिंग और डिलीवरी पार्टनर के लिए earnings/settlement विवरण के मौजूदा मॉड्यूल सुरक्षित हैं।
