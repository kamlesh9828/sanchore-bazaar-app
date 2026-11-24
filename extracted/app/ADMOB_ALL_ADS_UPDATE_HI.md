# Sanchore Bazaar – सभी AdMob विज्ञापन

Android के लिए उपयोगकर्ता द्वारा दिए गए असली AdMob IDs जोड़े गए हैं:

- App ID: `ca-app-pub-6141339446909248~2029595989`
- Banner: `ca-app-pub-6141339446909248/1441458533` – होम स्क्रीन पर पहले से उपयोग हो रहा था।
- Rewarded Video: `ca-app-pub-6141339446909248/2536203308` – पूरा वीडियो देखने पर ही reward callback मिलता है।
- Interstitial: `ca-app-pub-6141339446909248/2811535478` – ग्राहक दुकान से वापस आए तो हर 4वीं दुकान विजिट पर, केवल उपलब्ध होने पर। Checkout या payment के बीच नहीं दिखेगा।
- App Open: `ca-app-pub-6141339446909248/2203875862` – ऐप background से वापस आने पर अधिकतम 4 घंटे में एक बार, उपलब्ध होने पर।

iOS के लिए अलग IDs चाहिए; फिलहाल iOS IDs खाली रहने पर वहाँ ये विज्ञापन नहीं दिखेंगे। Web पर AdMob बंद है।

Reward points केवल RewardedAd के `onUserEarnedReward` callback में दिए जाने चाहिए। यह अपडेट बाकी ad formats को load/show करने की व्यवस्था जोड़ता है; AdMob से वास्तविक कमाई ad fill, impressions, invalid-traffic checks और account approval पर निर्भर है।
