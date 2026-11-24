# Sanchore Bazaar – सुधार स्थिति

## इस संशोधन में किए गए वास्तविक बदलाव

1. AdMob बैनर अब लोड होने पर ही जगह लेता है; विज्ञापन न मिलने पर ग्राहक ऐप में खाली जगह नहीं दिखेगी।
2. Debug build में AdMob की असफलता का कारण (error code/message) दिखाई देगा और Retry बटन से दोबारा विज्ञापन माँगा जा सकेगा। Production build में तकनीकी त्रुटि ग्राहक को नहीं दिखाई जाएगी।
3. Android और iOS के लिए अलग AdMob banner ad-unit ID रखी गई है। Android में प्रोजेक्ट की पहले से मौजूद ID उपयोग होती है। iOS ID को `--dart-define=ADMOB_IOS_BANNER_ID=...` से देना होगा; Android ID को iOS पर दोबारा उपयोग नहीं किया जाएगा।
4. कूपन बनाने/बंद करने का Admin पैनल, ग्राहक checkout में कूपन जाँच, दुकानदार का delivery estimate और Worker-side 5–240 मिनट validation पहले से मौजूद थे; इन्हें इस ZIP में रखा गया है।
5. Shopkeeper settlement और delivery earnings के immutable ledger तथा Admin के manual payment-reference confirmation endpoints पहले से मौजूद हैं।

## अभी क्या सक्रिय नहीं है / किसकी बाहरी मंजूरी चाहिए

- Paytm Split Settlement API इस प्रोजेक्ट में integrate/activate नहीं है। इसलिए किसी बैंक खाते में स्वचालित रकम भेजना अभी संभव नहीं है। मौजूदा `mark...Paid` endpoints केवल बाहरी भुगतान हो जाने के बाद reference दर्ज करते हैं; वे पैसा transfer नहीं करते।
- Cloudflare cron हर मिनट चलता है, लेकिन अभी केवल delivery offers और पुराने Paytm sessions संभालता है। इसे 11 PM payout भेजने वाला नहीं बताया गया है। वास्तविक payout तभी जोड़ा जा सकता है जब Paytm Split Settlement/अन्य marketplace payout API की merchant मंजूरी, vendor/partner IDs, KYC और सुरक्षित server credentials उपलब्ध हों। बैंक में credit का समय provider के settlement cycle पर निर्भर करेगा।
- AdMob ad-unit ID मौजूद होना विज्ञापन दिखने की गारंटी नहीं है। AdMob खाते में app/ad unit सक्रिय, policy-approved और fill उपलब्ध होना चाहिए। iOS के लिए अलग AdMob App ID `ios/Runner/Info.plist` में और अलग banner unit ID build define में सेट करनी होगी।
- Flutter/Dart SDK इस कार्य-पर्यावरण में उपलब्ध नहीं था; इसलिए Flutter compile, `flutter analyze`, Android APK और iOS build की पुष्टि नहीं की गई।

## सुरक्षा

कोई Paytm secret, Firebase service-account key, bank login, OTP या private key इस ZIP में न जोड़ें और चैट में साझा न करें। इन्हें केवल संबंधित provider के सुरक्षित server-side secret store में रखें।


## विज्ञापन ऑटो-रीट्राई अपडेट
- AdMob विज्ञापन फेल होने पर ऐप अब सीमित अंतराल पर अपने आप दोबारा कोशिश करता है: 30 सेकंड, 1 मिनट, 2 मिनट, 3 मिनट और फिर अधिकतम हर 5 मिनट।
- विज्ञापन सफल होने पर रीट्राई गिनती रीसेट होती है।
- ऐप बैकग्राउंड से वापस खुलने पर, यदि कोई रीट्राई पहले से तय नहीं है, तो विज्ञापन फिर लोड करने की कोशिश होती है।
- Debug मोड में कारण और मैनुअल Retry बटन दिखते हैं।
- AdMob की no-fill स्थिति, इंटरनेट, ऐप/AdMob अनुमोदन या विज्ञापन उपलब्धता के कारण हर बार विज्ञापन दिखने की गारंटी नहीं दी जा सकती।
