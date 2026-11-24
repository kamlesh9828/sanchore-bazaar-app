# Rewarded Video बटन हटाया गया (v26)

- ग्राहक की स्क्रीन से Rewarded Video कार्ड और उसका ‘चलाएँ’ बटन हटाया गया है।
- Rewarded Video अब ऐप शुरू होते ही preload या अपने-आप नहीं चलता।
- सामान्य Banner, App Open और Interstitial विज्ञापन पहले की तरह उपलब्ध रहते हैं।
- Google की नीति के अनुसार Rewarded Video को ग्राहक की स्पष्ट सहमति के बिना ऑटो-प्ले नहीं करना चाहिए।
- इसलिए इस संस्करण में वीडियो देखकर नए पॉइंट कमाने का ग्राहक वाला रास्ता बंद है। पहले से मौजूद वॉलेट बैलेंस और ऑर्डर में पॉइंट उपयोग की सुविधा हटाई नहीं गई है।
- SSV Worker में `reward_item=point` की जाँच भी जोड़ी गई है।

नोट: Flutter SDK उपलब्ध न होने के कारण इस ZIP का APK compile/live ad test नहीं किया गया। ZIP integrity और Worker JavaScript syntax जाँचना अलग से आवश्यक है।
