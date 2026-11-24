# V32 — ByteLabs Sender Email और OTP Logo

1. ByteLabs sender variable `BYTELABS_FROM_EMAIL` का सही मान `noreply@sanchorebazaar.bg5.net` रखा गया है।
2. OTP ईमेल HTML में Sanchore Bazaar का लोगो और footer जोड़ा गया है।
3. लोगो फ़ाइल `web/email-logo.png` में है। इसे वेबसाइट के public root पर `/email-logo.png` URL से प्रकाशित करना होगा।
4. Cloudflare Worker में `BYTELABS_FROM_EMAIL` Variable को `noreply@sanchorebazaar.bg5.net` पर सेट करके Worker redeploy करें। ZIP import से live Cloudflare settings अपने-आप नहीं बदलतीं।
5. OTP generation, expiry, resend cooldown, rate limits और verification logic में बदलाव नहीं किया गया है।
