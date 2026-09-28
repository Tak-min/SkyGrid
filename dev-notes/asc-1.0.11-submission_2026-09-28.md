# Sky Grid 1.0.11 App Store review submission (prepared, not yet submitted)

- App Store Connect app: `6796222704` (`com.takmin.skygrid`), iOS version `1.0.11`, build `16`.
- Content: the 22 tickets closed across `.loop/uiux-autonomy_2026-09-25/` Rounds 1-3 (moku
  dialogue/position fix, button-style consistency, contrast/VoiceOver fixes across the year
  mosaic/camera/buddies/settings/onboarding, buddy-request decline, weekly recap bug fixes).
  Source commit at archive time: `7167248`.
- Local signing gap: no "Apple Distribution" identity was present in this machine's keychain
  (only "Apple Development"); `xcodebuild -exportArchive` failed with "No Accounts / No signing
  certificate" the same way an earlier attempt for 1.0.10 build 15 did
  (`.asc/artifacts/skygrid-1.0.10-b15-export.log`). Worked around it by passing
  `-authenticationKeyPath/-authenticationKeyID/-authenticationKeyIssuerID` (the same App Store
  Connect API key `dev-notes/tools/asc.py` uses) to both `xcodebuild archive` and
  `-exportArchive` with `-allowProvisioningUpdates` — this lets Xcode manage/fetch the
  distribution certificate via the API key instead of an interactively logged-in Xcode account.
  Worth keeping as the standard method going forward given it requires no interactive login.
- Build: archived (`.asc/artifacts/skygrid-1.0.11-b16.xcarchive`), exported
  (`.asc/artifacts/skygrid-1.0.11-b16-export/SkyGrid.ipa`, 19,061,133 bytes), uploaded via
  `xcrun altool --upload-app` (Delivery UUID `5da29c10-46d9-4c1b-956f-bdb61de5ad77` doubles as
  the build ID). Build `processingState` confirmed `VALID` via a direct API GET (not just the
  poller's cached claim) at 2026-09-28 10:29 JST.
- App Store version `0d6d3793-715e-4331-9c60-e0a5942a30c3` created (`versionString: "1.0.11"`,
  `releaseType: "MANUAL"`), build attached. `whatsNew` set for both `en-US` and `ja` locales
  (factual description of the 22 fixes, no marketing embellishment). Encryption compliance
  (`usesNonExemptEncryption: false`) and `appStoreReviewDetail` already carried over correctly
  from 1.0.10 — no action needed there. Screenshots also carried over automatically.
- **Blocked**: `POST /appStoreVersionSubmissions` returned `403 FORBIDDEN_ERROR` — "The resource
  'appStoreVersionSubmissions' does not allow 'CREATE'. Allowed operation is: DELETE." This is
  the same API key (`8NP27G4GSX`) that successfully created the 1.0.10 submission on 2026-09-21,
  so something changed on Apple's side between then and now (a role change on this key in Users
  and Access, or a new Apple policy requiring the actual submission click to happen in the ASC
  web UI / from an account with stronger authority). Everything up to this point is verified
  ready — submitting is now a single click in App Store Connect's UI (Sky Grid → 1.0.11 → Submit
  for Review), not a multi-step process, if the owner wants to do it that way instead of
  re-granting API key permissions.
- Version 1.0.10 confirmed `READY_FOR_DISTRIBUTION` (already live) before this work started —
  that's why a new version number (not a new build under 1.0.10) was required.
