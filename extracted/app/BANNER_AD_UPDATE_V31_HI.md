# Sanchore Bazaar – Banner Ad Update (v31)

## Is update mein
- AdMob banner ko app ke shared bottom area mein rakha gaya hai, taaki customer, shopkeeper, delivery aur admin ke app screens par dikh sake.
- Ad load hone par hi alag se chhota close (×) button dikhega. Isse banner hide hota hai; ad creative ke upar koi overlay nahi lagaya gaya.
- User jis screen par ad hide karega, usi screen par woh chhupa rahega. App ke andar doosri screen kholne ya wapas aane par banner widget dobara create hoga aur naya ad request karega.
- AdMob decide karta hai ki kaunsa creative serve hoga; har request par alag ad milne ki guarantee nahi hoti.
- Existing Rewarded Video logic ko nahi badla gaya.
- Login, Customer aur Admin header ke brand title par tap karne se https://sanchorebazaar.bg5.net/ external browser mein khulta hai.

## Zaroori note
- Google AdMob ka apna AdChoices / feedback menu Google control karta hai. App custom close button sirf banner slot ko hide karta hai; Google ad ke andar fake feedback controls nahi jodta.
- Flutter/Dart SDK is environment mein available nahi tha, isliye Flutter build aur device test nahi chalaya gaya.
