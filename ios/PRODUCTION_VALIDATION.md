# Production Firebase invariants

- Physical-device Debug and Release builds use App Attest. Only Simulator Debug
  uses the registered App Check debug provider.
- A Firebase profile is created before RevenueCat is identified, so subscription
  webhooks always have an account document to update.
- Debug and Release app builds both identify against the production RevenueCat
  project. StoreKit Sandbox is the only permitted purchase-test environment for
  an installed app; never point an app build at a RevenueCat Test Store key.
- A photo is committed to Firestore before its outbox uploads either Storage
  object. The outbox retains the draft until both objects are present.
- Direct Storage access is owner-only. Buddy image bytes are served by the
  App-Check-enforced `imageDownloadURL` callable, which checks the exact post
  path, an accepted unblocked friendship, and that the caller posted that day.
  Images are capped at 2 MB, so the callable returns base64 bytes without
  granting the Functions runtime IAM signing permissions.

Useful checks:

```sh
cd functions && npm run lint && npm test
cd rules-tests && npm run test:emulator
```
