# Sanchore Bazaar v19 – Performance-only update

इस अपडेट में UI layout, रंग, fonts, buttons या v18 के button press animations में कोई बदलाव नहीं किया गया है।

## बदलाव
- छोटे product/cart thumbnails के लिए `cacheWidth` और `cacheHeight` सेट किए गए हैं, ताकि बड़ी तस्वीरों को छोटे स्थान पर दिखाते समय अनावश्यक memory decode कम हो।
- Admin ad preview thumbnails के decode size को भी सीमित किया गया है।
- कोई नया package/dependency नहीं जोड़ा गया।
- Button/UI polish वाला v18 code ज्यों का त्यों रखा गया है।

## अभी शेष जाँच
- इस environment में Flutter/Dart SDK उपलब्ध नहीं था, इसलिए `flutter analyze`, APK build और वास्तविक Android/iPhone performance test नहीं चलाया गया।
- Firestore search/report query optimization को इस अपडेट में नहीं बदला गया, क्योंकि बिना pagination/schema confirmation के limit लगाने से कुछ products/orders छूट सकते हैं।
