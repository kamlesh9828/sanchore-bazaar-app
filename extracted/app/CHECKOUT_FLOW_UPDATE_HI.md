# Sanchore Bazaar – नया Checkout Flow

## ग्राहक के लिए नया क्रम
1. कार्ट: मात्रा बदलें, सामान हटाएँ, और सामान जोड़ें। ADD और CONTINUE दोनों मुख्य हरे रंग में हैं।
2. कूपन और ऑफर: सक्रिय Firestore coupons दिखते हैं; न्यूनतम खरीद पूरी न होने पर कितनी राशि और जोड़नी है, यह दिखता है। APPLY से CouponService जाँच करता है।
3. पता: सेव पते, नया पता जोड़ने का रास्ता, और GPS पता उपलब्ध है। हर सेव पते की लोकेशन `service_areas` के सक्रिय radius से जाँची जाती है। क्षेत्र से बाहर पता चुनने/आगे बढ़ने नहीं दिया जाता।
4. भुगतान: COD (यदि Admin ने चालू रखा है) या सुरक्षित Paytm Checkout। Hosted checkout में उपलब्ध UPI Apps (PhonePe/Google Pay/Paytm UPI), Debit/Credit Card और Net Banking विकल्प gateway के अनुसार दिखेंगे।
5. Place Order: Worker server-side stock, coupon, fees, payment session और order status की गणना करता है।

## जरूरी कॉन्फ़िगरेशन / सीमाएँ
- Address serviceability के लिए Firestore `service_areas` में Admin द्वारा active center और radius सेट होना चाहिए। Saved addresses में latitude/longitude होना चाहिए; पुराने बिना GPS वाले पते Account में अपडेट करें।
- Online payment Paytm hosted checkout से है। UPI/PhonePe, Cards और Net Banking की वास्तविक उपलब्धता Paytm merchant account/checkout configuration पर निर्भर है; Flutter UI कोई नकली payment success नहीं दिखाती।
- COD का विकल्प `settings/payment.codEnabled` से नियंत्रित है; दुकान/ग्राहक स्तर पर backend restrictions भी लागू रहती हैं।
- Coupon की अंतिम पात्रता और discount Cloudflare Worker फिर से server-side जाँचता है। स्क्रीन पर दिखाई गई रकम अनुमान है; delivery/platform fees backend के हिसाब से जुड़ती हैं।
- Flutter SDK इस build environment में उपलब्ध नहीं था; इसलिए `flutter analyze`/APK build सत्यापित नहीं किया गया। Worker JavaScript syntax check और source delimiter sanity check किए गए।
