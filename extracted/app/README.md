# Sanchore Bazaar

Flutter marketplace project for Sanchore Bazaar (source revision 1.1.2+16). Customer, shopkeeper, delivery and admin roles share one Flutter application.

## Project structure

- `lib/main.dart` – app entry, login, role panels, product listing, cart/checkout and shared visual theme.
- `lib/screens/` – extended customer/admin/shopkeeper screens.
- `lib/services/` – Firebase, Worker API, cart, order, payment, delivery, address and admin services.
- `cloudflare-worker/worker.js` – authenticated backend using Firebase ID token validation and Firestore REST API.
- `firestore.rules` – Firestore access control; user registration profiles and reward ledger writes are Worker-only.

## Firebase and Cloudflare

Worker URL used by the app:

`https://sanchore-bazaar-api.kamlesh9828-kp.workers.dev`

Cloudflare Worker production variables/secrets:

| Type | Name | Purpose |
|---|---|---|
| Text | `FIREBASE_PROJECT_ID` | Firebase project ID (`sanchore-bazaar`) |
| Text | `FIREBASE_WEB_API_KEY` | Firebase Web API key |
| Secret | `FIREBASE_SERVICE_ACCOUNT_JSON` | Service account JSON contents |
| Text | `PAYTM_MID` | Paytm Merchant ID |
| Secret | `PAYTM_MERCHANT_KEY` | Paytm Merchant Key (16 characters) |
| Text | `PAYTM_ENV` | `STAGING` or `PRODUCTION` |
| Text | `PAYTM_WEBSITE_NAME` | `WEBSTAGING` or `DEFAULT` |
| Text | `WORKER_PUBLIC_URL` | Public Worker URL used for checkout return |
| Text | `ADMOB_REWARDED_AD_UNIT_ID` | Exact Android Rewarded Ad Unit ID used by SSV verification |

Keep the service account private key and all payment secrets in Cloudflare Secrets only. Never place them in Flutter source, Firestore, or chat.

Deploy the complete `cloudflare-worker/worker.js` file. `GET /health` checks that the Worker and required configuration are present. It does not replace signed-in end-to-end tests.

Publish `firestore.rules` in Firebase Console > Firestore Database > Rules.

## Included updates in this project revision

- Consistent Material 3 green marketplace theme, updated login branding, customer home welcome banner and refreshed product cards.
- Product unit field support (`piece`, `kg`, `gram`, `litre`, `ml`, `pack`) in product creation, Worker storage, product list, cart and order item snapshots. Stock/quantity remain integer values in this revision.
- Cart quantity increment/decrement and remove controls. Cart is cleared only after Worker confirms successful order creation.
- Customer order history no longer requires a composite `customerId + createdAt` index; the screen sorts results locally and displays the actual Firestore error if loading fails.
- Shopkeeper order cards have separate Accept, Reject, App Delivery and External Delivery actions. Worker rejection restores reserved stock atomically.
- Admin can enable/disable COD through a Worker-protected setting (`settings/payment`). Worker rejects new COD orders when disabled.
- Existing fee, settlement, refund, advertisement, product, shop, and order backend flows are retained.
- Customer-facing order, payment, ad and support statuses now use centralized Hindi labels; the order timeline accounts for an accepted delivery-partner assignment without changing the backend READY state.
- Admin has a live read-only revenue overview separating verified advertiser payments, delivered-order commission/platform fees, and amounts still payable to shops/riders.
- Reward-wallet redemption is capped server-side and in checkout preview at 25% of merchandise value per order to comply with Google-served rewarded-ad reward rules.

## Payment status

Checkout supports COD and Paytm Online. Admin can enable/disable COD. Paytm uses server-side Initiate Transaction and checksum generation, then verifies final status with Paytm Transaction Status API before orders become `paid`/`placed`. The client callback alone never marks an order paid. Configure the Paytm variables/secrets above and test with Staging credentials before Production. Unpaid sessions expire after 30 minutes through Cron and reserved stock is restored. The new checkout uses `webview_flutter`; run `flutter pub get`.

## Delivery status

Shopkeeper chooses App Delivery or External Delivery while accepting an order. Delivery staff can GO ONLINE/OFFLINE; GPS presence is refreshed every two minutes. The Worker selects the nearest fresh and available approved delivery person, sends a 60-second offer, and records Accept/Reject. A Cloudflare Cron Trigger runs once per minute to expire offers and search for the next candidate, so actual timeout handling can take 60–120 seconds. Add `* * * * *` under Cloudflare Dashboard > Worker > Settings > Triggers > Cron Triggers. `cloudflare-worker/wrangler.toml` includes the same trigger. External delivery needs no delivery staff account; shopkeeper marks it delivered after the order is READY.

## Location/service-area status

Checkout now accepts a normal readable address and 6-digit PIN code; manual latitude/longitude entry is not shown. GPS can reverse-geocode and fill the address. Admin can manage active delivery PIN codes, and the Worker validates the PIN code server-side. GPS coordinates are optional and retained internally when available; address-only orders will not have map-based customer coordinates for distance-based delivery assignment.

## Ads and Reward Wallet

The project includes Android AdMob App/Banner/Rewarded/Interstitial/App Open IDs. Rewarded video is user opt-in. The Worker verifies Google's signed AdMob SSV callback and credits exactly 1 point per verified completed ad; the client callback never writes points. The Customer Wallet shows the balance and ledger. 100 points = ₹1, redeemable at checkout after coupon discount. Configure the callback URL in AdMob and `ADMOB_REWARDED_AD_UNIT_ID` in Cloudflare before testing. Confirm that ad units are approved and have fill; real earnings depend on eligible impressions and AdMob account status.

## Firebase Web App connection (V33)

- Registered web client configuration for the existing Firebase project `sanchore-bazaar` is documented in `FIREBASE_WEB_SETUP_HI.md`.
- `lib/firebase_options.dart` already reads the web values from `--dart-define`; the native Android Firebase configuration remains unchanged.
- Run `./scripts_build_web.sh` (or follow the manual command in the Hindi setup guide) to build the Flutter web app into `build/web/`.
- This connects the Flutter web client to the same Firebase project as Android; shared login/data depends on using the same Auth providers, Firestore collections and security rules.
- The archive does not deploy to Cloudflare Pages automatically. Test the web build on a preview URL before changing the current public website.

## Before Build

See `BEFORE_BUILD_MANUAL_SETUP_HI.md` for required Cloudflare Worker deploy, AdMob SSV callback setup, Firestore Rules publish, Cron and live-test checklist. The app source is intentionally prepared before the APK build.

## Install and test

1. Back up the existing FlutLab project.
2. Import this ZIP as a Flutter project, or replace files while preserving the folder paths.
3. Run `flutter pub get`.
4. Publish `firestore.rules`.
5. Deploy `cloudflare-worker/worker.js` without deleting existing Worker variables/secrets.
6. Test login and customer, shopkeeper, Admin and delivery accounts on a test Firebase project or with test orders before production use.

The editing environment used to prepare this archive did not have the Flutter/Dart SDK, so `flutter analyze` and Android APK build could not be run here. Worker JavaScript syntax and XML/JSON configuration files are validated separately. Run Flutter analyzer/build in FlutLab before installing the APK.

## 2026-11-19 सुधार स्थिति

वास्तविक संशोधनों, अधूरे बाहरी भुगतान निर्भरता और परीक्षण सीमाओं के लिए `CHANGELOG_SUDHAR_HI.md` तथा `INSTALL_KRAM_HI.md` देखें। Paytm Split Settlement अभी सक्रिय/एकीकृत नहीं है; मौजूदा ledger endpoints वास्तविक बैंक transfer नहीं करते।

## Latest checkout and service-area update (1.0.2+4)
- Admin Dashboard now includes PIN-code delivery-area management (add, activate/deactivate, delete).
- Customer address eligibility checks configured active PIN codes; saved addresses without GPS can be used for PIN-based coverage. GPS radius remains available until PIN configuration is introduced.
- Shopkeeper cannot choose App Delivery when an order has no customer GPS coordinates; External Delivery remains available.
- Paytm initiate failures and terminal gateway failures mark pending orders failed and restore reserved stock atomically. Uncertain/pending transactions remain reserved until verified or the 30-minute expiry cron runs.
- See `FINAL_FEATURES_UPDATE_HI.md` for the remaining Paytm/AdMob account requirements and test limitations.


## AdMob Rewarded Video (Android)
- App ID: `ca-app-pub-6141339446909248~2029595989` (AndroidManifest.xml)
- Banner: `ca-app-pub-6141339446909248/1441458533`
- Rewarded: `ca-app-pub-6141339446909248/2536203308`
- Rewarded ads are loaded after MobileAds initialization. The client callback only displays status; the verified AdMob SSV Worker callback credits the wallet.
- Configure the AdMob SSV callback URL and Worker rewarded ad unit variable before enabling live rewards. See `BEFORE_BUILD_MANUAL_SETUP_HI.md`.


## Revenue and payment routing
- Advertiser Paytm payments are processed using the Cloudflare Worker `PAYTM_MID`; configure the owner's own approved Paytm Merchant account and its bank settlement details.
- AdMob earnings are paid separately to the bank account in the AdMob payments profile and are not automatically imported into the app.
- The Admin revenue screen reports recorded ad payments and delivered-order commission/platform fees separately from shopkeeper and delivery-partner payables. Ledger entries do not themselves transfer money.

## v23 Monetization update
See `CHANGELOG_V23_HI.md` and `MONETIZATION_ROADMAP_HI.md` for sponsored shop/product and local-business ad placement behavior, payment destination separation, and remaining Pro-membership scope.

## v30 Chat 106 update
See `CHANGELOG_CHAT106_V30_HI.md` for the combined Chat 106 feature checklist, shop-addition request workflow, Admin approval/rejection reason, and expanded Admin Pro status/Renew controls.
