# Sanchore Bazaar v15 – Login/Register Validation Update

## Changes
- Login email and password now show field-level error text.
- Invalid email format, empty email/password, and incorrect credentials get specific messages.
- Customer, shopkeeper, and delivery registration validate name, 10-digit mobile, email format, password length, and confirm-password match at the relevant field.
- Duplicate email and weak password errors appear under the email/password field.
- Google/Android Autofill hints and AutofillGroup from v14 are preserved.
- Forgot Password remains available.
- Password is passed unchanged at login (spaces are not silently trimmed).

## Important email verification limitation
This project currently uses Firebase Authentication's built-in **email verification link**, not a numeric OTP.
The Worker in this ZIP does not contain an email-sending provider integration (for example ByteLabs, Brevo, or SendGrid). A real numeric OTP with a 60-second resend timer, expiry, attempt limits, and server-side verification cannot be safely enabled until an email provider is selected and its API key is configured as a Cloudflare Worker secret.
No fake/local OTP has been added. Registration remains blocked at login until Firebase reports `emailVerified == true`.

## Testing
The ZIP structure was validated. Flutter/Dart SDK compilation was not available in this environment. Run Pub get and Build in FlutLab and share the first exact error if one appears.
