# Sky Grid localization stage 1 — 2026-09-12

## Scope

Implemented only stage 1 from `localization-en-ja-brief_2026-09-12.md`. Full app Japanese translation, widget/Live Activity language sharing, server notification localization, Firestore changes, App Store metadata, and other stage-2 work were intentionally not started.

## Language state and persistence

- Added `AppLanguage` (`en` / `ja`) and `LocalizationController` under `Sources/Localization`.
- The explicit choice is stored as `LocalDefaults.selectedLanguageCode` using the existing `@UserDefaultBacked` pattern.
- `nil` remains meaningful: no explicit in-app choice has been made yet.
- Automatic inference reads the first `Locale.preferredLanguages` entry: `ja` -> Japanese, everything else / unavailable -> English.
- Existing onboarded installs do not replay onboarding; they use inferred language until a language is explicitly selected in Settings.

## Immediate switching

SwiftUI invalidation and string lookup are handled separately:

1. `LocalizationController` is an observable root environment value. Changing it updates the root `.environment(\.locale, ...)`, causing the visible view tree to rerender immediately.
2. `LocalizationBundleOverride` installs a `Bundle.localizedString(forKey:value:table:)` override once at app startup. For `Bundle.main`, lookup is redirected to the selected language's `.lproj`. This is necessary because changing SwiftUI's locale alone does not change the process-selected `Bundle.main` localization used by existing localized `Text("...")` lookups.
3. `L10n.string(...)` is the explicit lookup path for non-View strings and stage-1 strings whose key is not represented as a literal SwiftUI localization key. Notifications, startup errors, the second-chance headline, and the adjusted Moku introduction use it.

### Known switching limits

- `SkyGridWidgets` and Live Activity remain device-language driven by design for stage 1. No App Group or entitlement change was made.
- Strings with no Japanese localization in `Localizable.xcstrings` intentionally remain English in stage 1. They are not a switching failure; their Japanese values belong to stage 2.
- Non-View code added later must use `L10n.string(...)` (or another explicit selected-language lookup) rather than assuming the process locale. No current `String(localized:)` calls were found under `ios/SkyGrid/Sources` during this implementation.

## Onboarding

- Added `.language` before `.welcome` in `OnboardingStep` and production onboarding starts there.
- Kept `OnboardingViewModel()`'s default start at `.welcome` so the existing onboarding unit test's pre-language flow remains valid without rewriting the test; `OnboardingCoordinatorView` explicitly initializes it with `.language` for shipped behavior.
- Japanese/English device language preselects the inferred language and shows confirmation copy.
- Other device languages start with no selection and cannot continue until English or Japanese is selected.
- A previously persisted explicit choice is restored on the language page after relaunch.
- Progress indicators were shifted from 9 pages to 10 pages.
- Welcome Moku copy now has the requested "late introduction" meaning in English and Japanese catalog entries.

## Settings

Added a Language menu to the existing EXPERIENCE section. Selection writes immediately, rerenders the app, and triggers language-specific morning notification resynchronization.

## Notifications

AlarmKit and local notification strings now use selected-language lookup. Language changes call `MorningAlarmScheduler.resyncLocalizedContent()` rather than ordinary `resyncIfNeeded()`, because the normal reconciliation intentionally skips schedules whose timing did not change. The language-specific path replaces the system-owned alert/notification content and refreshes the follow-up window without changing saved schedule definitions.

## Mixed Japanese moved out of Swift

Moved the three stage-1 mixed-language cases into `Localizable.xcstrings` with English as source behavior and Japanese localized values:

- second-chance paywall headline
- new-account startup error
- Apple sign-in startup error

A source scan after the change found no Japanese string literal remaining in Swift sources; Japanese stage-1 text lives in the String Catalog.

## XcodeGen / generated project

- Added `developmentLanguage: en` to `ios/project.yml`.
- `SkyGrid/Resources` is already a resources source in `project.yml`; the new `Localizable.xcstrings` contains `en` and `ja`, which XcodeGen uses when deriving project known regions.
- `project.pbxproj` was not edited directly.
- Per the owner's instruction, `xcodegen generate` and `xcodebuild test` were not run in this session; the owner will run them outside the local-MCP sandbox and verify generated `knownRegions` / `ja.lproj` and tests.

## Simulator verification procedure

After regeneration/build outside this sandbox:

1. Fresh onboarding, device language English: first page is language confirmation with English preselected.
2. Fresh onboarding, device language Japanese: first page is language confirmation with Japanese preselected.
3. Fresh onboarding, device language e.g. French: first page has no selection and Continue is disabled until a language is selected.
4. Toggle language on that page and in Settings; catalog-backed visible copy changes immediately without process restart.
5. Relaunch; explicit selection remains selected.
6. With morning alarms enabled, switch language and inspect pending/system alarm and follow-up copy to confirm it was rebuilt in the selected language.

## Stage-1 constraints preserved

No new analytics event type, paywall product/price/routing change, entitlement change, Firebase/server change, or existing test rewrite was made. `GoogleService-Info.plist`, `Secrets.xcconfig`, entitlements, `firebase.json`, and `ios/functions/` were not intentionally modified.
