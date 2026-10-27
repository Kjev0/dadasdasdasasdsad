# Releasing Fermata

Releases are built and published by CI (`.github/workflows/build.yml`) when a
`v*` tag is pushed. Branch pushes and pull requests only run the `test` job;
the packaging jobs run for `v*` tags and for manual runs (*Actions → Build →
Run workflow*, which produces downloadable artifacts but no release). How to
build by hand: [BUILDING.md](BUILDING.md).

## Versioning

`pubspec.yaml` is the single source of the version:

```yaml
version: 1.4.0+12      # <semver>+<build number>
```

| Part | Used as |
|---|---|
| `1.4.0` | User-visible version everywhere: Android `versionName`, Windows `AppVersion` (Apps list, installer), Linux `setup.sh --version` and install directory `~/.local/lib/fermata/1.4.0`, tarball name, git tag `v1.4.0` |
| `12` | Android `versionCode` (**must increase with every release**, or Android refuses the update); fourth part of the Windows file version (`1.4.0.12`) |

Semantic versioning: patch for fixes, minor for features, major for
incompatible changes (e.g. a library database migration that cannot be
rolled back). Pre-releases use a suffix (`1.5.0-beta.1+13`, tag
`v1.5.0-beta.1`); CI marks tags containing `-` as pre-releases.

## Release checklist

1. Make sure `main` is green in CI.
2. Bump `version:` in `pubspec.yaml` (raise the build number too).
3. Add a `<release version="1.4.0" date="YYYY-MM-DD">` entry at the top of
   `<releases>` in `packaging/linux/app.fermata.player.metainfo.xml`
   (software centers show it).
4. Commit, then tag and push:

   ```sh
   git tag -a v1.4.0 -m "Fermata 1.4.0"
   git push origin main v1.4.0
   ```

5. CI checks that the tag equals `v` + the pubspec version, runs the tests,
   builds `setup.exe`, `setup.sh`, the Linux tarball and `app.apk`, writes
   `SHA256SUMS` and creates the GitHub Release. Its body starts with short
   install instructions per platform, a link to [INSTALL.md](INSTALL.md), the
   checksum note, the Android certificate fingerprint (or a warning that
   `app.apk` is debug-signed) and a SmartScreen note when `setup.exe` is
   unsigned; GitHub's generated changelog follows.
6. Edit the release notes: add highlights and known issues.
7. Smoke-test the published files: download them, check `SHA256SUMS`, install
   on a clean Windows VM, a Linux VM (`./setup.sh`) and an Android device,
   and test an in-place update from the previous release.
8. Keep the `android-r8-mapping` artifact of the release run (it expires
   after 90 days): download it and store it with the release so Android stack
   traces can be deobfuscated.

Release asset names are stable and must not change: `setup.exe`, `setup.sh`,
`fermata-<version>-linux-x64.tar.gz`, `app.apk`, `SHA256SUMS`. Links in the
docs and the in-app update check rely on them.

## CI secrets and variables

Set them under *Settings → Secrets and variables → Actions*. Everything builds
without them; what changes is noted.

| Secret | Purpose | Without it |
|---|---|---|
| `FERMATA_KEYSTORE_BASE64` | Android release keystore, `base64 -w0 fermata-release.jks` | APK is debug-signed and the release notes warn about it |
| `FERMATA_KEYSTORE_PASSWORD`, `FERMATA_KEY_ALIAS`, `FERMATA_KEY_PASSWORD` | Keystore password, key alias, key password | as above (setting only some of them fails the build on purpose) |
| `WINDOWS_CERT_PFX_BASE64`, `WINDOWS_CERT_PASSWORD` | Authenticode certificate (.pfx, base64) and its password; signs `fermata.exe`, `setup.exe` and the uninstaller | `setup.exe` is unsigned |
| `FERMATA_DART_DEFINES_JSON` | Contents of a `dart_defines.json` compiled into all builds | Users enter credentials in the app |

| Variable | Purpose |
|---|---|
| `FERMATA_REQUIRE_RELEASE_SIGNING` = `true` | Strict mode: tag builds fail instead of publishing a debug-signed APK. Turn it on once the keystore secrets exist. |

A debug-signed `app.apk` installs and works, but users have to uninstall it
(losing the app's data) before they can install a later properly signed
build. Set up the keystore before the first release that many people will
install.

Notes:

* `FERMATA_DART_DEFINES_JSON` ends up inside public binaries, where anyone can
  extract it. Put only public client IDs in it, never client secrets or API
  keys you need to keep private ([CREDENTIALS.md](CREDENTIALS.md)).
* Pull requests from forks get no secrets and build debug-signed, unsigned
  artifacts; that is expected.
* Create the keystore secret without line breaks: `base64 -w0 fermata-release.jks`
  (Linux) or `[Convert]::ToBase64String([IO.File]::ReadAllBytes('fermata-release.jks'))`
  (PowerShell).

## Checksums and verification

Every release has `SHA256SUMS`, computed by CI from the files it uploads.
Users verify with `sha256sum --check --ignore-missing SHA256SUMS` (Linux) or
`Get-FileHash` (Windows), see [INSTALL.md](INSTALL.md#check-your-download).

`setup.sh` additionally embeds the SHA-256 of its payload and refuses to run
on a mismatch. That protects against truncated or corrupted downloads, not
against deliberate tampering: someone who can modify the file can also modify
the embedded checksum. Authenticity comes from downloading over HTTPS from
the project's release page and comparing with `SHA256SUMS` there.

Recommended next steps for stronger guarantees:

* Sign `SHA256SUMS` with a published OpenPGP key
  (`gpg --armor --detach-sign SHA256SUMS`) and upload `SHA256SUMS.asc`.
* Add GitHub artifact attestations (`actions/attest-build-provenance`) to the
  release job so users can run `gh attestation verify <file> --repo <owner>/<repo>`.

## Code signing

### Windows

`setup.exe` is **not code-signed** unless the `WINDOWS_CERT_*` secrets are
set. Unsigned installers trigger the SmartScreen "Windows protected your PC"
warning (users click *More info → Run anyway*), and some antivirus products
are more suspicious of them. Say so in the release notes.

To sign:

* Buy an OV code-signing certificate from a public CA, or use **Azure
  Artifact Signing** (formerly Trusted Signing; a Microsoft-managed
  certificate, about USD 10/month; available to organizations and individuals
  in some regions only).
* EV certificates no longer skip SmartScreen's reputation check; signed apps
  build reputation over time with downloads, and reputation is tied to the
  certificate ([Microsoft: SmartScreen reputation](https://learn.microsoft.com/en-us/windows/apps/package-and-deploy/smartscreen-reputation),
  [code signing options](https://learn.microsoft.com/en-us/windows/apps/package-and-deploy/code-signing-options)).
* Since 2023, CAs issue code-signing keys only on hardware tokens or cloud
  HSMs, so a new certificate usually cannot be exported as a `.pfx`. The
  workflow's `WINDOWS_CERT_PFX_BASE64` path works for exportable certificates;
  for HSM-backed certificates or Artifact Signing, pass your own signing
  command to the packaging script instead:

  ```powershell
  # $f = file to sign, $q = double quote (Inno Setup sign-tool syntax)
  .\tool\package_windows.ps1 -SignCommand '$qC:\tools\signtool.exe$q sign /v /fd SHA256 /tr http://timestamp.acs.microsoft.com /td SHA256 /dlib $qC:\tools\Azure.CodeSigning.Dlib.dll$q /dmdf $qC:\tools\metadata.json$q $f'
  ```

  (`FERMATA_SIGN_COMMAND` in the environment works too.) Always use a
  timestamp server so signatures stay valid after the certificate expires.

### Android

The release keystore is the app's identity: Android only installs an update
signed with the same key. **Back up the keystore and both passwords** in two
safe places; if they are lost, existing users can never receive updates and
must uninstall (losing their data) to switch to a new key.

Publish the certificate fingerprint in the release notes so users can check
it (`apksigner verify --print-certs app.apk`, "Signer #1 certificate SHA-256
digest"); `tool/build_android.sh` prints it.

If Fermata is ever published on Google Play, enrol in Play App Signing and
keep using this keystore as the upload key; sideloaded and Play builds then
differ in signature and cannot update each other.

### Linux

`setup.sh` and the tarball are not signed (Linux has no OS-level signature
check for them). Use `SHA256SUMS` (optionally signed, see above).

## Hotfixes and rollbacks

* Hotfix: branch from the release tag, fix, bump the patch version and build
  number, tag `v1.4.1`.
* A bad release cannot be "un-installed" remotely. Publish a fixed version
  with a higher build number; delete or mark the bad release as pre-release so
  the update check stops offering it. Never reuse a version number or tag.
* Downgrades: Windows and Linux installers accept an older version over a
  newer one (Linux warns). Android refuses a lower `versionCode`; users must
  uninstall first. Database migrations are one-way, so a downgrade may need a
  data reset.
