# Sanchore Bazaar – Delivery Assignment Fix

## इस अपडेट में
- दुकानदार के APP DELIVERY ऑर्डर को READY करते ही Worker तुरंत नजदीकी उपलब्ध डिलीवरी बॉय को ऑफर भेजने की कोशिश करता है।
- डिलीवरी बॉय GO ONLINE करे तो पहले से READY और प्रतीक्षा कर रहे ऑर्डर के लिए तुरंत असाइनमेंट प्रक्रिया चलती है।
- GPS heartbeat पर भी असाइनमेंट प्रक्रिया दोबारा चलती है।
- Cloudflare Cron fallback पहले की तरह बना रहता है।
- Delivery Panel में खाली सूची का संदेश अब बताता है कि GO ONLINE और GPS चालू रखें; नया ऑफर ऊपर दिखेगा।

## जरूरी सेटिंग
1. `cloudflare-worker/worker.js` को Cloudflare Worker में Deploy करें।
2. Cloudflare Cron Trigger `* * * * *` चालू रखें।
3. डिलीवरी बॉय ऐप में GO ONLINE दबाए, Location permission दे और GPS चालू रखे।
4. डिलीवरी बॉय का Admin approval पूरा होना चाहिए।
5. ग्राहक के ऑर्डर में GPS location होनी चाहिए; APP DELIVERY चुनने के लिए दुकान के पैनल में GPS उपलब्ध होना जरूरी है।

## परीक्षण
- डिलीवरी बॉय GO ONLINE करें।
- ग्राहक से GPS सहित नया ऑर्डर करें।
- दुकानदार APP DELIVERY स्वीकार करे, Preparing करे और READY दबाए।
- डिलीवरी बॉय के पैनल में NEW DELIVERY OFFER आना चाहिए। ACCEPT करने पर ऑर्डर Assigned सूची में आएगा।

Flutter SDK इस वातावरण में उपलब्ध नहीं था; इसलिए Flutter APK build/analyze नहीं किया गया। Worker JavaScript syntax check किया गया।

## इस संशोधन में अतिरिक्त सुरक्षा
- डिलीवरी ऑफर अब केवल दुकानदार के READY करने के बाद भेजा जाता है; Preparing के दौरान डिलीवरी बॉय को समय से पहले reserve नहीं किया जाता।
- एक ही READY ऑर्डर या डिलीवरी बॉय पर दो साथ चलने वाले dispatch अनुरोधों की race रोकने के लिए Firestore update-time precondition लगाई गई है।
- डिलीवरी बॉय ऑफर reject करे या offer expire हो, तो अगला नजदीकी उपलब्ध डिलीवरी बॉय तुरंत खोजा जाता है; Cron fallback भी जारी है।
