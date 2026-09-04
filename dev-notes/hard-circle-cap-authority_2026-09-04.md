# Hard circle-cap authority — implementation record (2026-09-04)

## Scope and observed gap

Product direction is an eight-person maximum buddy circle. `claimInviteCode` already
enforced that maximum, but handle-based requests still directly created and promoted
`friendships/{pairId}` from the client. Firestore Rules cannot count accepted edges,
so that path could create a ninth accepted relationship. The cap was therefore not a
real invariant.

This change moves both handle-path state transitions to Tokyo App-Check-enforced
callables:

- `requestBuddy` verifies the authenticated caller and the server-owned recipient
  handle mapping, then creates only a pending pair.
- `acceptBuddy` promotes that pending pair inside a transaction after counting each
  member's accepted, unblocked friendships. It returns `circleFull` or
  `buddyCircleFull` without mutating the pending request when the ninth edge would be
  created.
- `firestore.rules` now denies client creates and client status transitions for
  `friendships`; block/unblock and removal remain client-owned.

The iOS repository calls these callables and presents an explicit capacity message to
the person accepting a request. Pairwise relationship documents and the per-pair
mutual-reveal rule are unchanged.

## Verification

- Functions pure tests: 66 passing.
- Functions Firestore-emulator tests: 50 passing, including new direct-request,
  eighth/ninth acceptance, and idempotent-accept cases.
- Firestore/Storage Rules emulator tests: 38 passing; direct create and direct
  pending→accepted writes are denied.
- iOS Debug simulator build and focused `OrphanedPostRecoveryTests` passed. The test
  suite emits an existing Swift 6 warning in `BuddyPushPayloadTests` about
  `AnyHashable: Sendable`; this change does not add it.

## Release boundary — deliberately not executed

Nothing was deployed, pushed, or submitted. The code and Rules must **not** be
deployed as one blind operation: previously shipped clients use direct Firestore writes
and will lose handle-based buddy creation/acceptance as soon as the tightened Rules are
live.

Required release order is:

1. deploy only the new Functions;
2. ship the app version that uses `requestBuddy` / `acceptBuddy` and verify real-device
   callable success with App Check;
3. wait until an owner-selected minimum adoption threshold is reached, or explicitly
   accept that older builds must update for buddy changes;
4. deploy the Firestore Rules that deny direct relationship creation/promotion.

During steps 1–3, old builds can still bypass the cap. This is an unavoidable
compatibility window with the existing client-authority contract, not a condition that
can be solved in Firestore Rules by checking app version. The final Rules deployment
needs separate explicit authorization.
