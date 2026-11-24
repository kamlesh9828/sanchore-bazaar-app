# AdMob SSV चालू करने की प्रक्रिया (v25)

## सही Callback URL

`https://sanchore-bazaar-api.kamlesh9828-kp.workers.dev/api/admob/ssv`

## पहले Cloudflare Worker Deploy करें

1. Cloudflare Dashboard खोलें: https://dash.cloudflare.com/
2. **Workers & Pages** में `sanchore-bazaar-api` Worker खोलें।
3. **Edit code** चुनें।
4. ZIP के `cloudflare-worker/worker.js` की पूरी सामग्री Worker के editor में डालें।
5. **Deploy** दबाएँ।
6. Worker के Settings → Variables में यह variable रखें:
   - नाम: `ADMOB_REWARDED_AD_UNIT_ID`
   - मान: `ca-app-pub-6141339446909248/2536203308`
7. पहले से मौजूद Firebase variables और secrets को हटाएँ या बदलें नहीं।

## Worker का URL जाँचें

ऊपर दिया Callback URL ब्राउज़र में खोलें। सही Deploy होने पर JSON में `AdMob SSV endpoint is active` दिखना चाहिए। इस जाँच से कोई पॉइंट नहीं जुड़ता।

## Firebase Rules प्रकाशित करें

1. Firebase Console → Firestore Database → Rules खोलें।
2. ZIP की `firestore.rules` फ़ाइल की पूरी सामग्री Rules editor में डालें।
3. **Publish** दबाएँ।

इससे reward sessions केवल Worker लिख सकेगा और ग्राहक केवल अपना reward history पढ़ सकेगा।

## AdMob में URL Verify और Save करें

1. https://admob.google.com/ खोलें।
2. Apps → **Sanchore Bazaar** चुनें।
3. Ad units → Rewarded ad unit खोलें।
4. Server-side verification (SSV) / Advanced settings खोलें।
5. Callback URL में ऊपर दिया URL डालें।
6. Custom data का अलग मान न भरें; ऐप हर विज्ञापन के लिए सुरक्षित one-use session ID खुद भेजता है।
7. **Verify** दबाएँ और सफल होने पर **Save** दबाएँ।
8. Reward amount `1` और reward item `point` रखें। Worker केवल reward_amount `1` स्वीकार करता है।

## सुरक्षा कैसे काम करती है

- ऐप पहले Worker से एक बार इस्तेमाल होने वाला reward session बनवाता है।
- ऐप यह session ID AdMob के `custom_data` में भेजता है।
- Google signed SSV callback भेजता है। Worker Google की public key से ECDSA signature जाँचता है।
- सही signature, सही Android rewarded ad unit, सही ग्राहक और चालू session होने पर ही 1 पॉइंट जुड़ता है।
- एक ही `transaction_id` दोबारा آئے तो دوبارہ पॉइंट नहीं जुड़ता।
- ऐप का client callback अकेले पॉइंट नहीं जोड़ सकता।

## ज़रूरी सीमाएँ

- इस स्रोत में Worker JavaScript syntax जाँचा गया है; Cloudflare पर Deploy, AdMob में Verify/Save, Google से live callback और वास्तविक wallet credit अभी आपके Dashboard में करना बाकी है।
- iOS Rewarded Ad ID अभी अलग से सेट नहीं है।
- किसी API key, private key या service-account JSON को AdMob Callback URL में न डालें।
