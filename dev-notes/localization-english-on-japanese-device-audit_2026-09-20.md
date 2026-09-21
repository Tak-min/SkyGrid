# English selection on a Japanese device — localization audit (2026-09-20)

The earlier claim of complete localization was too broad. This audit used a Japanese-language iPhone 17 simulator (iOS 26.5) with Sky Grid set to English. It distinguishes app-owned copy from controls owned by iOS.

## Verified in the running app

- In Settings, switched to Japanese and back to English, relaunched the app, opened the initial paywall, and tapped Close. The second-chance headline, renewal label, and purchase button appeared in English. A separate test confirmed the corresponding Japanese path. UI audit uses deterministic products and does not verify a real RevenueCat offering.
- Morning Alarms settings displayed English labels and alarm summaries under the same English-on-Japanese-device condition.
- The compact Dynamic Island displayed “Capture” and its accessibility label was “Sky Grid morning, Open camera” with English selected. A UI test started the activity in Japanese, changed the selection to English, then verified that the running Dynamic Island's accessibility label changed to English. The widget previously looked up its own bundle using the device language; it now receives the app selection in ActivityKit content state. Existing activities are refreshed at app startup and on language changes.
- The account access screen still showed “Appleでサインイン” inside Apple's `SignInWithAppleButton` while the app-owned surrounding text was English. Apple documents that its system button uses the device language. Replacing it would require a custom Sign in with Apple button built from Apple-provided artwork and preserving the existing authorization behavior; the artwork download presented an Apple license agreement and was not accepted in this session.

## Code paths checked and changed

- Correction: retaining the catalog key and pinning a locale was insufficient. The user observed Japanese in the physical AlarmKit UI with English selected. `L10n.resource` now uses app-selected text as a fallback under an opaque key in a separate table, so a device-locale lookup cannot replace it from the catalog. An unchanged persisted alarm or fallback reminder is refreshed after launch and on language change; focused tests serialize the resource and override its locale before resolving it.
- The two alarm App Intent titles and the AlarmKit permission explanation are static system-resolved copy. Their Japanese catalog entries now use English too, preventing app-authored Japanese text when English is selected. Japanese app users will also see these three items in English.
- RevenueCat prices use the selected app locale, and SDK/OS purchase error descriptions no longer reach the paywall UI. Paywall state and purchase outcome messages use catalog entries.
- The Live Activity extension reads its translations from the app language code carried in `ContentState`. The code is optional so older activities still decode. ActivityKit content state encoding compatibility is tested.
- Device language writes for server push registration are serialized so a slower prior write cannot overwrite a newer selection. Firebase delivery and a failed remote write were not exercised against a live backend.
- All 808 main catalog keys and 15 widget keys have both `en` and `ja` entries. No English catalog value contains Japanese script. Swift source contains no Japanese UI literal outside tests/comments. These static checks cannot prove every runtime state.

## Limits

The focused simulator run passed 40 unit tests (alarm resource/reconciliation, Live Activity state compatibility, startup failures), four localization UI tests (paywall, persisted Settings choice, alarm settings, running Live Activity switch), and the existing Dynamic Island UI test. The simulator Release configuration also built successfully; `git diff --check` passed.

- The Apple-provided sign-in button and some iOS-owned alerts/actions still follow the device language. The app cannot claim full English separation while the Japanese sign-in button remains.
- The user exercised the old AlarmKit full-screen UI on a physical device and observed Japanese with English selected. The revised code's physical-device full-screen presentation is still unverified; the simulator checks cover the app's English alarm settings and the resource/scheduler behavior, not that OS-rendered presentation.
- Previously delivered notifications and already displayed system UI cannot be rewritten after a language switch. Future server notifications use the device document's language field once its update succeeds.
