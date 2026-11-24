# Sanchore Bazaar – सुधार (19-11-2026)

## ऐप में किए गए बदलाव
- ग्राहक Home Page से विज्ञापन रिक्वेस्ट का बटन हटाया; विज्ञापन सुविधा दुकानदार के पैनल में रहेगी।
- ग्राहक Home Page पर कार्ट का बटन जोड़ा, ताकि सेव किया हुआ कार्ट सीधे खुल सके।
- ऐप दोबारा खोलने पर पहले से लॉगिन ग्राहक/दुकानदार/Admin का सेशन वापस खोलने के लिए Session Restore जोड़ा। इससे उसी अकाउंट का Firestore Cart बना रहेगा और दोबारा Login स्क्रीन पर नहीं फँसेगा।
- सामान कार्ट में जुड़ने का संदेश 1.4 सेकंड में हटेगा; लंबे समय तक स्क्रीन पर नहीं रहेगा।
- Admin में किसी ग्राहक या दुकान के लिए COD अलग से चालू/बंद करने का स्विच जोड़ा।
- दुकानदार के प्रोडक्ट के साथ हटाने का बटन जोड़ा; हटाने से पहले पुष्टि पूछी जाएगी। हटाने पर प्रोडक्ट ग्राहक को नहीं दिखेगा।
- PIN कोड जोड़ने/बदलने/हटाने और ग्राहक के PIN की जाँच के लिए सुरक्षित Cloudflare Worker API जोड़ी; PIN के लिए सीधे Firestore client write/read पर निर्भरता हटाई।
- विज्ञापन रिक्वेस्ट के Worker endpoints शामिल हैं; रिक्वेस्ट केवल सक्रिय दुकानदार भेज सकेगा।
- ऐप वर्जन 1.0.3+6 किया।

## जरूरी: Cloudflare Worker भी Deploy करें
ऐप के विज्ञापन में `Endpoint not found` इसलिए आ सकता है क्योंकि Cloudflare पर पुराना Worker चल रहा है। ZIP में `cloudflare-worker/worker.js` नया है। इसे Cloudflare Dashboard में `sanchore-bazaar-api` Worker के code से बदलकर **Deploy** करें। Worker के मौजूदा Variables/Secrets और Cron Trigger को न हटाएँ।

Deploy के बाद `https://sanchore-bazaar-api.kamlesh9828-kp.workers.dev/health` खोलकर देखें कि API चल रही है।

## जाँच की स्थिति
- Cloudflare Worker JavaScript syntax check सफल।
- ZIP archive integrity check सफल।
- Flutter SDK इस वातावरण में उपलब्ध नहीं था; इसलिए Android APK/Flutter compile की पुष्टि नहीं की गई। FlutLab में नया ZIP खोलकर Build चलाना जरूरी है।
