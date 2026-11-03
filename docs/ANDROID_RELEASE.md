# Android release setup

## What the current APK is

The first APK was built before a permanent upload key was configured. It is suitable for testing, but it is not yet the long-term update channel. Android requires every update of an installed app to be signed with the same certificate.

**Important:** if you install the current test APK, you will need to uninstall it once before installing the first APK signed with the permanent key. After that, keep the keystore safe and every later release can update the app in place.

## 1. Create a permanent upload keystore

Do this on a trusted computer with JDK installed. Open Terminal / PowerShell in a private folder and run:

```bash
keytool -genkeypair -v -keystore bandplan-upload.jks -storetype JKS -keyalg RSA -keysize 4096 -validity 10000 -alias bandplan-upload
```

- When prompted, create a strong keystore password.
- Enter the requested certificate details.
- Set a key password when prompted (it may be the same as the keystore password).
- Keep `bandplan-upload.jks`, both passwords, and the alias in a password manager / secure backup.
- Never upload the JKS file to GitHub, commit it, or send it in chat. If this key is lost, future compatible APK updates cannot be signed with the same certificate.

## 2. Convert the keystore to Base64

GitHub Actions needs a one-line Base64 representation of the JKS file. This is not encryption; the value must remain a secret.

**Windows PowerShell:**

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("bandplan-upload.jks")) | Set-Clipboard
```

This copies the Base64 value to the clipboard.

**Linux:**

```bash
base64 -w 0 bandplan-upload.jks
```

**macOS:**

```bash
base64 bandplan-upload.jks | tr -d '\n'
```

Copy the complete output without spaces or line breaks.

## 3. Add four GitHub Actions secrets

Open the repository:

**Settings → Secrets and variables → Actions → New repository secret**

Create these four repository secrets:

| Secret name | Value |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | Complete Base64 output from step 2 |
| `ANDROID_KEYSTORE_PASSWORD` | Keystore password |
| `ANDROID_KEY_ALIAS` | `bandplan-upload` |
| `ANDROID_KEY_PASSWORD` | Password for the key |

Do not put these values in repository Variables, source files, workflow YAML, issues, or chat.

The Android build also uses the existing backend configuration:
- Repository **Variable** `SUPABASE_URL`
- Repository **Secret** `SUPABASE_PUBLISHABLE_KEY`

Do not replace these with service-role credentials.

## 4. Start a signed APK build

Adding secrets does not start a workflow by itself.

1. Open the repository's **Actions** tab.
2. Select **Build Android APK**.
3. Click **Run workflow**.
4. Select branch `main` and run it.
5. Open the run and wait until all steps are green, especially **Configure persistent Android release signing**, **Build release APK**, and **Publish latest APK release**.
6. Open the Android release and download `BandPlan-android.apk`.

If the signing secrets are complete, the workflow configures the release build with the permanent key. If they are missing, it intentionally falls back to a test build; do not treat that APK as the final update channel.

## 5. Install and update

- If you have never installed BandPlan, install the first APK built after the permanent key has been configured.
- If you installed the earlier test APK, uninstall that one once, then install the permanently signed APK. The signing certificates differ, so Android will not install it over the test build.
- After that, do not delete or replace the keystore. Future APKs signed with the same key can be installed over the previous version.
- Keep the Android package identity unchanged. Version/build number must increase for each published update.

## Quick troubleshooting

- **Android says “App not installed”:** check whether an older APK with a different signing certificate is installed; uninstall the old test build once.
- **Signing step fails:** verify the Base64 value is complete, the alias is exactly `bandplan-upload`, and both passwords match the keystore.
- **APK build succeeds but login/backend does not work:** verify `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY` are configured in repository settings.
- **Release asset is missing:** check that the workflow reached and passed **Publish latest APK release**.
