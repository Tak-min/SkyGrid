# Alarm language regression — 2026-09-20

## Observed failure

Correction after a physical-device report: the previous "fix" below did not
resolve the visible alarm. The user observed Japanese AlarmKit copy with English
selected in Sky Grid. The earlier simulator unit test proved only local Foundation
lookup; it did not prove the system alarm UI. Its conclusion was too strong.

`LocalizedStringResource` is serialized and resolved by another process. Apple
documents that the resolving process can replace `resource.locale` with
`.current`, so retaining the catalog key plus an English locale is not enough.

On the Japanese iPhone 17 simulator, the focused `MorningAlarmSchedulerTests` test failed before the fix: `L10n.resource("notification.captureSky", language: .english)` had key `"Capture the sky"` and locale `ja`. The Japanese case had key `"空を撮ろう"`. The app had translated the catalog key into a value before handing a `LocalizedStringResource` to AlarmKit, whose lookup is deferred. This allowed AlarmKit to use the device locale again, even when English was selected in the app.

Separately, `resyncIfNeeded()` reconciled persisted AlarmKit alarms and fallback reminders by time and weekdays only. An unchanged schedule kept the text captured when it was previously scheduled. A language change normally called `resyncLocalizedContent()`, but older content could survive a failed or missed refresh; a later cold launch did not replace it.

## Fix and check

Revised fix: `L10n.resource` now resolves the selected app language in process,
then places that string in `LocalizedStringResource.defaultValue` under distinct
opaque keys per field and selected language in a separate catalog table. Thus a
later device-locale lookup has no
translation entry that can replace the selected text. Main and retry AlarmKit
presentations both call this helper. The launch resync replaces enabled AlarmKit
presentations and fallback reminders after schedule reconciliation. Fallback
requests retain their IDs and are replaced without first removing the existing
request, so a failed add does not create a gap. Language resync also replaces
pending same-day retry alarms with their existing IDs and fire dates.

Two App Intent titles (`Open Sky Grid` and `Sky Grid morning alarm stopped`)
are compiled as static metadata and follow the device language. Their Japanese
catalog values are now English, as is the AlarmKit permission explanation in
`InfoPlist.xcstrings`. These system-resolved, app-authored strings will therefore
remain readable with English selected on a Japanese device. The OS-owned Stop
control still follows iOS language and is outside the app's localization path.

The earlier focused suite failed before the initial fix (22 passed, 1 failed),
then passed after it (24 passed, 0 failed), but the physical alarm remained
Japanese. The revised tests specifically serialize the resource, override its
locale with the other device language, and assert that the app-selected text
survives. Code inspection confirms that the main and retry AlarmKit alert
factories both call this helper for their title and camera button. A physical
AlarmKit ring after the revised fix still requires verification;
do not describe these tests as an end-to-end display check.

An attempted simulator ring through a temporary Debug-only audit route was
blocked by `AlarmManager.authorizationState == .denied`, even after resetting
the app's simulator privacy permissions. The route was removed after this check.
The running app's Morning Alarms settings UI test did pass with English selected
on the Japanese simulator. The simulator block does not confirm the full-screen
AlarmKit presentation on the user's physical device.
