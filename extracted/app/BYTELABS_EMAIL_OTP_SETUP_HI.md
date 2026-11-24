# Sanchore Bazaar — ByteLabs Email OTP सेटअप

इस अपडेट में ग्राहक, दुकानदार और डिलीवरी पार्टनर के रजिस्ट्रेशन से पहले 6 अंकों का ईमेल OTP भेजने के लिए ByteLabs Email API जोड़ी गई है। OTP की मौजूदा सुरक्षा बरकरार है: 5 मिनट expiry, 60 सेकंड resend cooldown, 15 मिनट में अधिकतम 5 भेजने के अनुरोध और अधिकतम 5 गलत प्रयास। OTP का hash ही Firestore में रखा जाता है।

## Cloudflare Worker में सेटिंग

Cloudflare Dashboard → Workers & Pages → `sanchore-bazaar-api` → Settings → Variables and Secrets में:

**Secret (Encrypt/Secret):**
- `BYTELABS_MAIL_KEY` — ByteLabs की Live API key (`bm_live_` से शुरू)। इसे केवल Secret में रखें।
- `OTP_HASH_SECRET` — पहले से इस्तेमाल हो रहा कम-से-कम 32 अक्षरों का अलग random secret। अगर पहले से मौजूद है तो वही रखें।

**Plain variable:**
- `BYTELABS_FROM_EMAIL` — `noreply@sanchorebazaar.bg5.net` (आपका verified custom sender domain)।

फिर Worker Deploy करें। `/health` में `emailOtpConfigured: true` दिखना चाहिए।

## Sender और Logo
- Sender variable का मान `noreply@sanchorebazaar.bg5.net` रखें। यह Worker में `from` address के रूप में जाएगा; ZIP बदलने से Cloudflare के live Variables/Secrets अपने-आप नहीं बदलते।
- OTP ईमेल में Sanchore Bazaar का लोगो `https://sanchorebazaar.bg5.net/email-logo.png` से लोड होगा। इस ZIP में `web/email-logo.png` जोड़ा गया है। इसे वेबसाइट के public root पर `/email-logo.png` नाम से प्रकाशित करना जरूरी है, तभी ईमेल में लोगो दिखेगा।

## जरूरी बातें
- API key Flutter ऐप में न डालें; केवल Cloudflare Worker Secret में रखें।
- Free shared sender address से भेजे गए ईमेल में ByteLabs footer रहेगा।
- ByteLabs API `POST /emails` पर ईमेल queue करती है; Worker OTP खुद बनाता और Firestore में hash रखता है, इसलिए ऐप का मौजूदा OTP verify flow बना रहता है।
- यदि sender address गलत/अनुमत नहीं है या free quota/limit पूरी है, तो भेजना असफल होगा।

## Deploy के बाद जाँच
1. Cloudflare Worker Deploy करें।
2. `/health` खोलकर `emailOtpConfigured: true` देखें।
3. ऐप में test registration करके अपने ही ईमेल पर OTP भेजें।
4. OTP verify करके ही Firebase registration आगे बढ़ेगा।

इस ZIP में Worker source और Flutter app source शामिल हैं। FlutLab में ZIP import करके build log जाँचें; APK build होने का दावा नहीं किया गया है।


## अतिरिक्त सुरक्षा
ग्राहक प्रोफाइल अब Cloudflare Worker से ही बनता है। Worker जाँचता है कि OTP उसी Firebase खाते के ईमेल के लिए पिछले 30 मिनट में सत्यापित हुआ हो। दुकानदार/डिलीवरी आवेदन पर भी यही जाँच लागू है। इसके लिए अपडेटेड `firestore.rules` Firebase Console में Publish करना जरूरी है; अब ऐप सीधे customer profile create नहीं कर सकता।
