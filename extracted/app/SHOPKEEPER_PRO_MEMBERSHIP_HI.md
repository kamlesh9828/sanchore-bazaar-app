# दुकानदार Pro सदस्यता – v24

## योजनाएँ
- मासिक: ₹299 / 30 दिन
- वार्षिक: ₹2,999 / 365 दिन
- कीमतें डिफ़ॉल्ट हैं; Admin > मेरी कमाई और भुगतान > दुकानदार Pro नियंत्रण से बदली जा सकती हैं।

## चालू सुविधाएँ
- सक्रिय सदस्यता पर दुकान के नाम के साथ Pro बैज।
- ग्राहक की दुकान सूची में सक्रिय Pro दुकानें पहले दिखाई जाती हैं।
- दुकानदार अपनी दुकान चुनकर सदस्यता की स्थिति, बचा समय और समाप्ति देख सकता है।
- मासिक/वार्षिक सदस्यता Paytm से खरीदी जाती है।
- Paytm status Worker पर सत्यापित होने के बाद ही सदस्यता सक्रिय होती है।
- पहले से सक्रिय सदस्यता के रहते renewal खरीदने पर नई अवधि मौजूदा expiry के बाद जुड़ती है।
- सदस्यता स्वतः renew नहीं होती; दुकानदार अवधि पूरी होने पर फिर भुगतान करता है।
- Admin कीमत बदल सकता है, Pro रोक सकता है और वैध अवधि रहते बहाल कर सकता है।
- Admin रिपोर्ट में Pro से प्राप्त सफल भुगतान अलग दिखते हैं।

## सर्वर endpoints
- `POST /api/shopkeeper/proInfo`
- `POST /api/shopkeeper/createProPayment`
- `POST /api/admin/shopkeeperProSettings`
- `POST /api/admin/saveShopkeeperProPrices`
- `POST /api/admin/setShopkeeperProStatus`
- मौजूदा `POST /api/paytm/initiate` और `POST /api/paytm/verify` भुगतान पूरा करते हैं।

## जरूरी सेटअप
1. `cloudflare-worker/worker.js` Deploy करें।
2. `firestore.rules` Publish करें ताकि Pro सदस्यता रिकॉर्ड केवल मालिक और Admin पढ़ सकें; लिखना Worker तक सीमित रहे।
3. Paytm Merchant का मौजूदा `PAYTM_MID` और `PAYTM_MERCHANT_KEY` सही होने चाहिए।
4. वास्तविक भुगतान के लिए पहले Paytm STAGING पर परीक्षण करें, फिर Merchant की अनुमति के अनुसार PRODUCTION चालू करें।

## सीमाएँ
- अभी Pro में केवल बैज और दुकान सूची में प्राथमिकता लागू है; कोई guaranteed sales, search ranking, sponsored product quota या revenue guarantee नहीं दी जाती।
- यह recurring mandate नहीं है; हर अवधि के लिए दुकानदार को अलग भुगतान करना होगा।
- Flutter Build और वास्तविक Paytm भुगतान परीक्षण इस पैकेज में नहीं किए गए।
