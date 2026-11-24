# Sanchore Bazaar v24 – Shopkeeper Pro Membership

1. दुकानदार पैनल में Pro सदस्यता स्क्रीन जोड़ी: दुकान चयन, योजना, स्थिति, शेष दिन और expiry.
2. ₹299 / 30 दिन और ₹2,999 / 365 दिन के शुरुआती प्लान; Admin कीमत बदल सकता है।
3. Paytm भुगतान के Worker-side status verification के बाद ही Pro सदस्यता सक्रिय होती है।
4. Renewal पर मौजूदा वैध expiry के बाद 30/365 दिन जोड़े जाते हैं।
5. सक्रिय Pro दुकानें ग्राहक की दुकान सूची में पहले आती हैं और Pro बैज दिखता है।
6. Admin Revenue में Pro सदस्यता के सफल भुगतान अलग दिखते हैं; Admin कीमत, रोकना और बहाल करना नियंत्रित कर सकता है।
7. Firestore में `shopkeeper_subscriptions` के लिए read-only owner/Admin access जोड़ा; writes Worker-only हैं।
8. Pending/failed/expired Paytm Pro sessions के लिए subscription status cleanup जोड़ा।

## परीक्षण
- Cloudflare Worker JavaScript syntax check पास।
- ZIP integrity check पास।
- Flutter SDK इस वातावरण में उपलब्ध नहीं था; Flutter analyze/build और real Paytm transaction test नहीं किया गया।
