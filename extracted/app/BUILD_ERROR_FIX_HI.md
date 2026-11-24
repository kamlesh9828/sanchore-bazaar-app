# Build error fix

`lib/main.dart` में coupon validation का result nullable (`Map<String, dynamic>?`) था। अब code पहले null check करता है और discount को `num` होने की पुष्टि के बाद `double` में बदलता है। इससे दिए गए `Operator [] cannot be called on Map?` compile error का कारण ठीक किया गया है।

Flutter/Gradle build इस वातावरण में चलाकर सत्यापित नहीं किया गया है; FlutLab में नया ZIP import करके Release build चलाएँ।
