# Firebase setup required for Sky Grid

The iOS target intentionally has no local/demo backend. Before running it against a
real service, create a Firebase iOS app whose bundle identifier is
`com.takmin.skygrid`, enable Anonymous Authentication, Firestore, and Storage, then
add that app's `GoogleService-Info.plist` to `SkyGrid/Resources/` in Xcode.

Deploying `firestore.rules`, `storage.rules`, or `functions/` changes a remote
service. It is therefore intentionally not performed by the source build. Use a
dedicated staging project first, configure App Check for the callable account-delete
endpoint, and run the Rules Emulator authorization cases before any production
deployment.

## RevenueCat entitlement webhook

The app gets immediate purchase access from RevenueCat on-device. The
`revenueCatWebhook` Function keeps the server-side `entitlements/{uid}` snapshot
in sync for trusted backend use; clients cannot read or write that collection.

Before enabling it in a staging project:

1. Deploy the Function and set the Firebase secret named
   `REVENUECAT_WEBHOOK_AUTHORIZATION` to a long random Authorization header value.
2. In the RevenueCat dashboard, add the deployed Function URL as a webhook, set
   that exact Authorization header, and enable the purchase, renewal,
   cancellation, expiration, product-change, and billing-issue lifecycle events.
3. Send a RevenueCat dashboard test event and confirm only the expected
   `monthly`, `annual`, or `lifetime` product creates an entitlement snapshot.

The mobile offering must expose only these paid product identifiers:
`com.takmin.skygrid.pro.monthly`, `com.takmin.skygrid.pro.annual`, and
`com.takmin.skygrid.pro.lifetime`. Remove the former three-day introductory
offer from App Store Connect and RevenueCat before production rollout; this
source deliberately has no trial state or trial copy.
