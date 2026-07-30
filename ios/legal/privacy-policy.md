# Sky Grid — Privacy Policy

_Last updated: 2026-07-30_

Sky Grid ("the app") is a morning photo streak app. This policy describes what
data the app collects, why, and how you can delete it.

## Data we collect

| Data | Why | Where it's stored |
|---|---|---|
| Account identifier (anonymous ID, or your Apple ID if you choose Sign in with Apple) | To identify your account and sync your data across devices | Firebase Authentication |
| Handle / display name | Shown to your buddies | Firebase Firestore |
| Your morning sky photos, capture time, and extracted color | The core feature of the app | Firebase Cloud Storage / Firestore |
| Streak count, wake-goal time, subscription (Pro) status | To power the app's core mechanics and paywall | Firebase Firestore |
| Buddy relationships (who you've connected with) | To show buddy posts and enforce mutual-blur | Firebase Firestore |
| Push notification device token | To send your morning reminder and buddy-posted notifications | Firebase Cloud Messaging |
| In-app purchase receipt data | To grant Pro entitlements | RevenueCat, Apple (StoreKit) |

We do **not** collect your photo library, contacts, location, or browsing
history, and the app has no advertising or analytics SDK.

## Who we share data with

- **Firebase (Google)** — hosts our backend (authentication, database, photo
  storage, push notifications, and account-deletion logic).
- **RevenueCat** — manages subscription state; receives your anonymized
  purchase/entitlement data, not your photos or profile.
- **Apple** — processes payments for subscriptions and in-app purchases via
  StoreKit; Sign in with Apple is optional.

We do not sell your data, and we do not share it with advertisers.

## Buddies and visibility

Your morning photo is visible only to buddies you've mutually accepted. Until
you post your own photo for the day, a buddy's photo stays blurred to you (and
vice versa). You can remove a buddy or block a relationship at any time from
the app, which immediately revokes their access to your photos.

## Reporting and moderation

If you see a photo or profile that concerns you, you can report it from within
the app. Reports are reviewed and are not visible to other users.

## Deleting your data

You can permanently delete your account and all associated data (profile,
photos, streak history, buddy relationships) from Settings → Delete Account.
This is handled by a server-side function and cannot be undone.

## Children's privacy

Sky Grid is not directed at children under 13, and we do not knowingly collect
data from children under 13.

## Changes to this policy

If this policy changes in a way that materially affects how your data is
used, we'll update the "Last updated" date above and, where required, notify
you in-app.

## Contact

Questions about this policy or your data: **{{SUPPORT_EMAIL}}**
