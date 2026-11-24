# स्टॉक और भुगतान सुधार

- कार्ट में सामान जोड़ने से पहले Firestore से लाइव स्टॉक जाँचा जाता है।
- कार्ट में मात्रा बढ़ाने/घटाने पर भी लाइव स्टॉक जाँचा जाता है।
- Checkout से पहले प्रत्येक सामान का स्टॉक दोबारा जाँचा जाता है।
- Cloudflare Worker ऑर्डर बनाते समय स्टॉक और उपलब्धता जाँचता है; कम स्टॉक पर स्पष्ट त्रुटि देता है और स्टॉक अपडेट को Firestore updateTime precondition के साथ commit करता है, जिससे एक ही बचा स्टॉक दो ग्राहकों को नहीं बिकता।
- स्टॉक शून्य या active=false होने पर ग्राहक को Out of Stock दिखता है।
- ऑनलाइन भुगतान Paytm CheckoutJS के माध्यम से है। UPI Apps, QR, कार्ड और नेट बैंकिंग की वास्तविक उपलब्धता Paytm Merchant खाते/गेटवे में सक्षम instruments पर निर्भर है; कोड अकेले बंद merchant instruments चालू नहीं कर सकता।

Cloudflare Worker में `cloudflare-worker/worker.js` Deploy करना आवश्यक है। Flutter Build FlutLab में जाँचें।
