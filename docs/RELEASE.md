# Releasing to TestFlight

[`.github/workflows/release-testflight.yml`](../.github/workflows/release-testflight.yml)
builds a Release archive and uploads it straight to App Store Connect — the whole
build/sign/export/upload sequence is automated. What it **can't** automate is
anything that requires an actual Apple account: those are one-time steps only the
Apple Developer Team owner can do, below.

## 1. One-time Apple Developer Portal / App Store Connect setup

Do this once, before the first release (needs an active
[Apple Developer Program](https://developer.apple.com/programs/) membership — $99/yr,
enrolled as the individual or organization that will own this app):

1. **Pick a real bundle ID prefix.** `project.yml` ships with the placeholder
   `com.mikedotjs.deltasleep` (see its own comment) — pick your real reverse-DNS
   domain instead, e.g. `com.yourcompany.deltasleep`. You don't edit `project.yml`
   for this; the release workflow substitutes it from a secret (§2).
2. **Register two App IDs** in
   [Certificates, Identifiers & Profiles](https://developer.apple.com/account/resources/identifiers/list):
   - `<your-bundle-id-prefix>` (the app) — enable the **HealthKit** and
     **App Groups** capabilities.
   - `<your-bundle-id-prefix>.widget` (the widget extension) — enable
     **App Groups** only.
3. **Create the App Group** `group.<your-bundle-id-prefix>` and attach it to both
   App IDs above — this is the shared container `Packages/SnapshotStore` uses to
   pass the cached debt snapshot from the app to the widget.
4. **Create an App Store Connect API key**: App Store Connect →
   [Users and Access → Integrations → App Store Connect API](https://appstoreconnect.apple.com/access/integrations/api) →
   generate a key with the **App Manager** role. Note the **Key ID** and
   **Issuer ID**, and download the `.p8` file — Apple only lets you download it
   once, so save it somewhere safe immediately.
5. **Create the app record**: App Store Connect → My Apps → **+** → New App.
   Bundle ID must match `<your-bundle-id-prefix>` from step 1 (it'll appear in the
   picker once step 2 is done); set the name, primary language, and SKU. This step
   is what actually makes "upload a build" mean something — `xcodebuild` can sign
   and upload a binary, but it can't create the app record itself.
6. **Create an Apple Distribution certificate** — required once per team, and
   `-allowProvisioningUpdates` will *not* do this for you (see "Known limitation"
   below for why). Generate a key + CSR locally, upload it, download the cert,
   and package it as a `.p12` the workflow can import into a throwaway CI keychain:
   ```sh
   openssl genrsa -out dist.key 2048
   openssl req -new -key dist.key -out dist.csr \
     -subj "/emailAddress=you@example.com/CN=Your Name/C=FR"
   ```
   Upload `dist.csr` at [Certificates → +→ Apple Distribution](https://developer.apple.com/account/resources/certificates/add),
   download the resulting `.cer`, then:
   ```sh
   openssl x509 -inform DER -in distribution.cer -out dist.pem
   # -legacy matters: OpenSSL 3.x's default PKCS12 encryption (AES-256 +
   # SHA256 MAC) isn't something macOS's `security import` can parse — it
   # fails with a misleading "MAC verification failed (wrong password?)"
   # even when the password is correct. -legacy forces the older
   # RC2/SHA1 encryption `security` actually understands.
   openssl pkcs12 -export -legacy -inkey dist.key -in dist.pem -out dist.p12 \
     -passout "pass:$(openssl rand -hex 24 | tee dist_p12_password.txt)" \
     -name "CI Distribution"
   ```
   Keep `dist.key`, `dist.p12`, and `dist_p12_password.txt` somewhere safe (outside
   the repo) — §2 needs the `.p12` and its password as secrets.
7. **App Privacy questionnaire** (App Store Connect → App Privacy): answer
   truthfully that Health & Fitness data is collected but not linked to identity
   and not used for tracking — nothing leaves the device (see
   `NSHealthShareUsageDescription` in `project.yml` and the onboarding copy in
   `App/DeltaSleep/OnboardingView.swift`, both already say this to the user).

## 2. GitHub repository secrets

Settings → Secrets and variables → Actions → New repository secret, one per row:

| Secret | Value |
|---|---|
| `BUNDLE_ID_PREFIX` | The real bundle ID prefix from step 1 above, e.g. `com.yourcompany.deltasleep` |
| `APPLE_TEAM_ID` | Your 10-character Team ID (Apple Developer → Membership) |
| `APP_STORE_CONNECT_KEY_ID` | The Key ID from step 4 |
| `APP_STORE_CONNECT_ISSUER_ID` | The Issuer ID from step 4 |
| `APP_STORE_CONNECT_API_KEY_P8_BASE64` | The `.p8` file's contents, base64-encoded — see below |
| `APPLE_DISTRIBUTION_CERTIFICATE_P12_BASE64` | The `.p12` from step 6, base64-encoded — same trick as below |
| `APPLE_DISTRIBUTION_CERTIFICATE_PASSWORD` | The password you generated for that `.p12` in step 6 |

To produce the base64 secrets from the downloaded `AuthKey_XXXXXXXXXX.p8` / `dist.p12`:

```sh
base64 -i AuthKey_XXXXXXXXXX.p8 | tr -d '\n' | pbcopy   # macOS, copies to clipboard
# or, portably:
base64 -w0 AuthKey_XXXXXXXXXX.p8                        # Linux, prints it
```

Paste the resulting single line as the secret's value.

## 3. Run it

Actions tab → **Release to TestFlight** → Run workflow. It will:

1. Substitute your real bundle ID into a throwaway checkout (never committed —
   `project.yml` and the two `.entitlements` files stay as placeholders in git).
2. `xcodegen generate`, then archive with automatic signing (the App Store Connect
   API key lets `xcodebuild -allowProvisioningUpdates` fetch or create the needed
   provisioning profiles without any interactive Apple ID login).
3. Export and upload the `.ipa` straight to App Store Connect, using this GitHub
   Actions run number as the build number (so every run is uploadable — App Store
   Connect rejects a re-used build number).

A successful run doesn't mean the build is immediately installable — Apple
processes every upload (usually 5–30 minutes; occasionally longer) before it shows
up under App Store Connect → TestFlight → Builds. Once it's there:

- **Internal testers** (your own App Store Connect team, up to 100 people): add
  them under the internal testing group — no Apple review, available within
  minutes of processing finishing.
- **External testers**: needs a lightweight Apple beta review first (usually
  24–48 hours), then testers install via the public or emailed TestFlight link.

Optionally set a "What to Test" note per build in App Store Connect → TestFlight
→ (your build) → Test Details — the upload itself doesn't carry one.

## Known limitations of this pipeline

`-allowProvisioningUpdates` reliably auto-creates missing **provisioning
profiles**, and can register a missing **App ID**, but attaching a **new** App
Group capability to an App ID the very first time has been unreliable across
Xcode versions when driven headlessly. If the archive step fails complaining
about the App Group entitlement specifically, double-check step 3 above was done
manually in the portal before re-running — that one part may need a human in the
loop even with the API key.

It also reliably auto-creates **Apple Development** certificates on demand, but
never **Apple Distribution** ones — confirmed by testing, not just docs: repeated
CI runs against a team with zero Distribution certs kept auto-creating fresh
Development certs and archiving with those, and export then failed uploading
with "Invalid Signature" (code 90035), because Apple's server correctly rejects
a binary that was never actually distribution-signed. Step 6 above (create the
cert once, ship it as a secret, import into a throwaway keychain each run) works
around this — there's no way to make `-allowProvisioningUpdates` create the
Distribution certificate itself.
