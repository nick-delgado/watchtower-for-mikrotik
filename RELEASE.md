# Release Notes & Concerns

Things to resolve before public release on the App Store and Google Play. Revisit at Phase 6
(see [PLAN.md](PLAN.md)).

## "MikroTik" trademark in the app name

- Apple App Review Guideline 5.2.1: don't use third-party trademarks without permission, or names
  and metadata that suggest an affiliation. "X for MikroTik" apps can pass, but a reviewer can
  reject. Google Play has a similar impersonation / IP policy.
- Options:
  - Ask MikroTik for permission to use the name.
  - Keep the name but add a clear "not affiliated with or endorsed by MikroTik" disclaimer in the
    app and store listing.
  - Rename, using "MikroTik" only descriptively in the subtitle or description.
- Check MikroTik's published trademark guidance before deciding.

## GPLv3 vs. the App Store

- This repo is licensed GPLv3. The App Store's terms add usage restrictions that the FSF considers
  incompatible with GPL's "no further restrictions" clause (VLC was pulled from the App Store over
  this in 2011).
- As the **sole copyright holder** you can still publish your own code. The problem starts when
  other people contribute GPL code, or if the app pulls in GPL-licensed dependencies.
- Options:
  - Keep GPLv3 and require a CLA or copyright assignment from contributors.
  - Add an App Store exception to the license (a GPLv3 section 7 "additional permission").
  - Switch to a permissive or weak-copyleft license (MIT, Apache-2.0, MPL-2.0) before accepting
    outside contributions.
- Audit dependency licenses (most Flutter packages are BSD, MIT, or Apache — compatible).
- Google Play has no equivalent conflict.

## Store requirements

- Accounts: Apple Developer Program (annual fee) and a Google Play developer account (one-time fee).
  New personal Play accounts must run a closed test with a minimum number of testers before
  production — check the current rules.
- A privacy policy URL is required by both stores.
- Privacy labels (Apple) and the Data safety form (Play): credentials are stored on the device
  only, and no data is collected or sent anywhere except the user's own router.
- Permission justifications: iOS Local Network usage string; Android `ACCESS_LOCAL_NETWORK`.
- **App review without a router:** reviewers won't have a MikroTik. Provide a demo mode (recorded
  data via the fake transport) and explain it in the review notes.
- Export compliance: the app only uses standard TLS, which normally qualifies for the exemption
  (`ITSAppUsesNonExemptEncryption = NO`). Confirm at submission.
