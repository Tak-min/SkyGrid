# Sky Grid 1.0.10 App Store review submission

- App Store Connect app: `6796222704` (`com.takmin.skygrid`), iOS version `1.0.10`, build `15`.
- Source commit: `dcce41a` (`fix: honor selected language across alarm and app surfaces`).
- IPA: `.asc/artifacts/skygrid-1.0.10-b15.ipa`; SHA-256 `f1ec8568b21879e7db1e0bdf4e1b6c0f275af3330e33afeb0954587b19cc39b4`.
- Build ID: `d4699f41-877f-4f94-9d5b-5877431a4bf2`; version ID: `e616db91-5a36-4921-ae7c-5cfa3fee6b99`.
- Submission ID: `1429a511-cdc6-48fb-92c6-0467fb636b7d`; submitted `2026-09-21T02:13:39.24Z`.
- App Store Connect reported `WAITING_FOR_REVIEW` for both version and latest submission after submission. Release type is `MANUAL`; approval alone will not publish it.
- Validation before submission: 359 `SkyGridTests` passed; targeted alarm settings UI test passed; ASC validation found 0 blocking issues. The three warnings concerned optional subscription promotional images. Remote en-US and ja release notes were checked after staging.
- Limitation: the full-screen AlarmKit alert with the app language set to English on a Japanese-language physical iPhone was not directly observed after the fix. The source and compiled localization were checked, but that behavior must not be reported as physically verified.
