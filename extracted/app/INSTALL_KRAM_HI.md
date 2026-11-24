# अपडेट लगाने का तरीका

1. इस ZIP को डाउनलोड करके Extract करें।
2. FlutLab में अपने पुराने project की सुरक्षित copy/backup रखें।
3. Extract किए project की पूरी source files को FlutLab project में replace/import करें; केवल `main.dart` बदलना पर्याप्त नहीं है।
4. Cloudflare Worker उपयोग हो रहा है तो `cloudflare-worker/worker.js` और `wrangler.toml` को अपने Worker project में deploy करें। Deploy से पहले Cloudflare secrets/variables पहले जैसे सुरक्षित रूप से configured होने चाहिए।
5. Firestore rules में बदलाव तभी deploy करें जब आप इसी project की पूरी rules file उपयोग कर रहे हों और मौजूदा Firebase rules का backup ले लिया हो।
6. Android पर app चलाकर AdMob की स्थिति जाँचें। Debug build में विज्ञापन की त्रुटि और Retry दिखेगा। Production में ad fail होने पर खाली जगह नहीं दिखेगी।
7. iOS build के लिए अलग iOS AdMob App ID Info.plist में और banner unit ID `ADMOB_IOS_BANNER_ID` define से configure करें।

## भुगतान के बारे में

यह ZIP Paytm Split Settlement को चालू नहीं करती। पहले Paytm Merchant Support से marketplace/split settlement activation, vendor onboarding और payout API access की पुष्टि लें। उसके बाद ही provider API जोड़कर sandbox tests और वास्तविक bank settlement verification किया जा सकता है। केवल ledger में `paid` लिखना बैंक transfer नहीं है।

## जरूरी परीक्षण

- Admin login: coupon बनाना और active/inactive करना।
- Customer checkout: सही/गलत/बंद coupon लगाना।
- Shopkeeper login: delivery estimate 5 से 240 मिनट के बीच save करना; दूसरे दुकानदार की दुकान बदलने का प्रयास अस्वीकार होना चाहिए।
- Android: AdMob load / no-fill / retry व्यवहार।
- Order: delivered होने पर shopkeeper settlement और delivery earning ledger बनना।
- Manual payout: पैसा वास्तव में भेजने के बाद ही सही bank/UPI reference के साथ paid mark करना।


### विज्ञापन अपने आप दोबारा लोड होना
नई ZIP में AdMob Banner फेल होने पर सीमित अंतराल से ऑटो-रीट्राई है। सफल होने पर रीट्राई टाइमर बंद हो जाता है। यह विज्ञापन की उपलब्धता की गारंटी नहीं है। iOS पर अलग AdMob App ID और Banner Ad Unit ID देना अभी भी जरूरी है।


## विज्ञापन सिस्टम — पूरा सेटअप (एक बार करना जरूरी)

1. Cloudflare Dashboard → Workers & Pages → `sanchore-bazaar-api` → Settings → Bindings → Add → **Workers AI** चुनें।
2. Binding variable name बिल्कुल `AI` रखें और Save/Deploy करें। ZIP के `cloudflare-worker/wrangler.toml` में भी `[ai] binding = "AI"` जोड़ा गया है। Workers AI उपयोग पर Cloudflare की usage/billing शर्तें लागू हो सकती हैं; यह असीमित मुफ्त सेवा नहीं है।
3. Worker के `worker.js` का पूरा नया कोड Deploy करें। पहले से मौजूद Firebase और Cloudinary variables/secrets न हटाएँ।
4. Firebase Console में इसी ZIP की `firestore.rules` Publish करें; विज्ञापन लिखने/बदलने के अधिकार Worker के Admin endpoints से नियंत्रित हैं।
5. ऐप के Admin → विज्ञापन प्रबंधन → सेटिंग में 7/15/30 दिन की कीमत, अपना UPI ID और QR फोटो चुनकर सेव करें।
6. ग्राहक/दुकानदार ऐप में “विज्ञापन दें” से व्यवसाय का नाम, मोबाइल और प्रचार की जानकारी भेजेंगे। वे विज्ञापन डिजाइन, URL, अवधि या कीमत नहीं बना सकते।
7. Admin → नई विज्ञापन रिक्वेस्ट → विज्ञापन बनाएँ → “AI से विज्ञापन और फोटो बनाएँ” दबाएँ। AI से लिखावट और फोटो बनेगी; जरूरत हो तो एडमिन फोटो गैलरी से बदल सकता है। फिर ड्राफ्ट बनाएँ और राशि तय करें।
8. ग्राहक को ऐप में UPI/QR और राशि दिखेगी। भुगतान के बाद वह UTR भेजेगा। Admin अपने बैंक/UPI में वास्तविक जमा जाँचकर ही “भुगतान जाँचें / चालू करें” दबाए। Worker खुद बैंक से पैसा verify नहीं कर सकता।
9. विज्ञापन अवधि 7/15/30 दिन के बाद Active Ads सूची से अपने आप हट जाता है। सक्रिय विज्ञापन न होने पर Home पर Sanchore Bazaar का fallback बैनर दिखता है।

**सुरक्षा:** AI generation route Admin role जाँचता है। ग्राहक/दुकानदार केवल अपनी रिक्वेस्ट और अपने कैंपेन देख/भुगतान UTR भेज सकते हैं। वे विज्ञापन बना, बदल या लाइव नहीं कर सकते।

**सीमा:** Cloudflare AI binding चालू और Worker deploy किए बिना AI बटन काम नहीं करेगा। Cloudflare और Firebase Dashboard में Deploy/Publish आपके खाते से ही करना होगा; इस चैट से आपके खातों में लॉगिन करके ये बदलाव प्रकाशित नहीं किए जा सकते।
