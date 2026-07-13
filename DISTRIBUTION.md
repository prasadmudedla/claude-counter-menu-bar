# Distribution

GitHub Actions creates a DMG whenever a tag beginning with `v` is pushed. The release contains the DMG and `SHA256SUMS.txt`.

## Create an unsigned test release

No secrets are required. The asset name contains `-unsigned`, and the workflow marks it as a prerelease. macOS Gatekeeper will warn users because it has not been signed by an identified Apple developer or notarized.

```sh
git tag v1.0.0
git push origin v1.0.0
```

## Create a public notarized release

Direct distribution without a Gatekeeper warning requires membership in the Apple Developer Program, a **Developer ID Application** certificate, hardened runtime signing, and Apple notarization.

Add these repository secrets under **Settings → Secrets and variables → Actions**:

| Secret | Value |
| --- | --- |
| `BUILD_CERTIFICATE_BASE64` | Base64-encoded Developer ID Application `.p12` export |
| `P12_PASSWORD` | Password used when exporting the `.p12` |
| `APPLE_API_PRIVATE_KEY_BASE64` | Base64-encoded App Store Connect API `.p8` key |
| `APPLE_API_KEY_ID` | App Store Connect API key ID |
| `APPLE_API_ISSUER_ID` | App Store Connect API issuer ID |

Encode the certificate and API key on macOS:

```sh
base64 -i DeveloperID.p12 | pbcopy
base64 -i AuthKey_ABC123.p8 | pbcopy
```

When all five secrets exist, the workflow imports the certificate into a temporary keychain, signs the app with hardened runtime, signs the DMG, submits it with `notarytool`, staples the accepted ticket, and publishes the notarized DMG.

## Release a new version

Update both version values in `Info.plist`, commit the change, and push a matching tag:

```sh
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString 1.1.0" Info.plist
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion 2" Info.plist
git add Info.plist
git commit -m "Release 1.1.0"
git push
git tag v1.1.0
git push origin v1.1.0
```

The workflow also supports manual runs from **Actions → Release DMG → Run workflow**.
