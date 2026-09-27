# Telegram Plus

Telegram Plus is a minimal fork of the **official Telegram iOS** client
(`TelegramMessenger/Telegram-iOS`). It keeps the original architecture, behaviour
and feature set, and changes exactly two things in the chat list UI.

Both changes are **fixed behaviour**: they are always on, and there is no setting
anywhere in the app to turn them off or back on.

## 1. Chat List swipe actions are disabled

Swiping a row in the chat list no longer reveals actions (pin, mute, read, delete,
archive, …). The action set itself is unchanged — every one of those actions is
still available through the existing long-press / context menu, the archive
context menu, or chat list edit mode. No capability was removed; only the way it
is reached changed.

The one action that upstream exposed *only* through a swipe — hiding/unhiding the
General topic of a forum — was added to the forum topic long-press menu so it
stays reachable.

Accessibility: the VoiceOver custom actions for a chat row are untouched, so the
full action set remains available to assistive technology.

## 2. No side topics panel inside forums

Inside a forum/monoforum topic, upstream can show a vertical topics strip on the
left edge (92 pt) when the "sidebar" panel mode is selected. Telegram Plus never
shows it: the left space is given to the forum/topic interface instead.

Topics remain fully reachable through the standard top/bottom topics header panel,
which stays available and toggleable exactly as upstream. Normal chats and the
regular chat list outside forums are unaffected.

## Building

Builds run on GitHub Actions via `.github/workflows/build-telegram-plus.yml`
(macOS runner, Bazel). The workflow provisions `build-system/fake-codesigning`,
regenerates the fake profiles for the fork's bundle id
(`build-system/Make/RegenerateProfilesForBundle.py`) and builds with
`build-system/telegram-plus-configuration.json`.

Resulting `.ipa` is unsigned; sideload it with SideStore / AltStore / Feather.
The bundle id is `ph.telegra.TelegramPlus`, so it installs alongside the official
Telegram app.

---

# Telegram iOS Source Code Compilation Guide

We welcome all developers to use our API and source code to create applications on our platform.
There are several things we require from **all developers** for the moment.

# Creating your Telegram Application

1. [**Obtain your own api_id**](https://core.telegram.org/api/obtaining_api_id) for your application.
2. Please **do not** use the name Telegram for your app — or make sure your users understand that it is unofficial.
3. Kindly **do not** use our standard logo (white paper plane in a blue circle) as your app's logo.
3. Please study our [**security guidelines**](https://core.telegram.org/mtproto/security_guidelines) and take good care of your users' data and privacy.
4. Please remember to publish **your** code too in order to comply with the licences.

# Quick Compilation Guide

## Get the Code

```
git clone --recursive -j8 https://github.com/TelegramMessenger/Telegram-iOS.git
```

## Setup Xcode

Install Xcode (directly from https://developer.apple.com/download/applications or using the App Store).

## Adjust Configuration

1. Generate a random identifier:
```
openssl rand -hex 8
```
2. Create a new Xcode project. Use `Telegram` as the Product Name. Use `org.{identifier from step 1}` as the Organization Identifier.
3. Open `Keychain Access` and navigate to `Certificates`. Locate `Apple Development: your@email.address (XXXXXXXXXX)` and double tap the certificate. Under `Details`, locate `Organizational Unit`. This is the Team ID.
4. Edit `build-system/template_minimal_development_configuration.json`. Use data from the previous steps.

## Generate an Xcode project

```
python3 build-system/Make/Make.py \
    --cacheDir="$HOME/telegram-bazel-cache" \
    generateProject \
    --configurationPath=build-system/template_minimal_development_configuration.json \
    --xcodeManagedCodesigning
```

# Advanced Compilation Guide

## Xcode

1. Copy and edit `build-system/appstore-configuration.json`.
2. Copy `build-system/fake-codesigning`. Create and download provisioning profiles, using the `profiles` folder as a reference for the entitlements.
3. Generate an Xcode project:
```
python3 build-system/Make/Make.py \
    --cacheDir="$HOME/telegram-bazel-cache" \
    generateProject \
    --configurationPath=configuration_from_step_1.json \
    --codesigningInformationPath=directory_from_step_2
```

## IPA

1. Repeat the steps from the previous section. Use distribution provisioning profiles.
2. Run:
```
python3 build-system/Make/Make.py \
    --cacheDir="$HOME/telegram-bazel-cache" \
    build \
    --configurationPath=...see previous section... \
    --codesigningInformationPath=...see previous section... \
    --buildNumber=100001 \
    --configuration=release_arm64
```

# FAQ

## Xcode is stuck at "build-request.json not updated yet"

Occasionally, you might observe the following message in your build log:
```
"/Users/xxx/Library/Developer/Xcode/DerivedData/Telegram-xxx/Build/Intermediates.noindex/XCBuildData/xxx.xcbuilddata/build-request.json" not updated yet, waiting...
```

Should this occur, simply cancel the ongoing build and initiate a new one.

## Telegram_xcodeproj: no such package 

Following a system restart, the auto-generated Xcode project might encounter a build failure accompanied by this error:
```
ERROR: Skipping '@rules_xcodeproj_generated//generator/Telegram/Telegram_xcodeproj:Telegram_xcodeproj': no such package '@rules_xcodeproj_generated//generator/Telegram/Telegram_xcodeproj': BUILD file not found in directory 'generator/Telegram/Telegram_xcodeproj' of external repository @rules_xcodeproj_generated. Add a BUILD file to a directory to mark it as a package.
```

If you encounter this issue, re-run the project generation steps in the README.


# Tips

## Codesigning is not required for simulator-only builds

Add `--disableProvisioningProfiles`:
```
python3 build-system/Make/Make.py \
    --cacheDir="$HOME/telegram-bazel-cache" \
    generateProject \
    --configurationPath=path-to-configuration.json \
    --codesigningInformationPath=path-to-provisioning-data \
    --disableProvisioningProfiles
```

## Versions

Each release is built using a specific Xcode version (see `versions.json`). The helper script checks the versions of the installed software and reports an error if they don't match the ones specified in `versions.json`. It is possible to bypass these checks:

```
python3 build-system/Make/Make.py --overrideXcodeVersion build ... # Don't check the version of Xcode
```
