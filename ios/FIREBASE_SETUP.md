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
