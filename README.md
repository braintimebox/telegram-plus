# Telegram Plus

Telegram Plus is a minimal fork of the **official Telegram iOS** client
(`TelegramMessenger/Telegram-iOS`). It keeps the original architecture, behaviour
and feature set. The chat list UI changes below are the point of the fork;
everything else exists only to make the result installable, launched and
diagnosable on a device without a Mac.

Every change below is **fixed behaviour**: it is always on, and there is no
setting anywhere in the app to turn it off or back on.

## 1. Chat List swipe actions are disabled

Swiping a row in the chat list no longer reveals actions. The action set itself
is unchanged — every action upstream offered by swipe is still available through
the long-press / context menu, the archive context menu, or chat list edit mode.
No capability was removed; only the way it is reached changed.

Full inventory of the swipe actions and where each one lives now:

| Swipe action | Reached through |
| --- | --- |
| Pin / Unpin | `ChatList_Context_Pin` / `_Unpin` (long-press menu) |
| Mute / Unmute | `ChatList_Context_Mute` / `_Unmute`, plus "Mute for…" |
| Mark as read / unread | `ChatList_Context_MarkAsRead` / `_MarkAsUnread` |
| Archive / Unarchive | `ChatList_Context_Archive` / `_Unarchive` |
| Delete | `ChatList_Context_Delete` |
| Add to folder / Remove from folder | `ChatList_Context_RemoveFromFolder` |
| Group / Ungroup (communities) | `ChatList_Context_Ungroup` |
| Close / Reopen topic | `ChatList_Context_CloseTopic` / `_ReopenTopic` |
| Hide / Unhide General topic | forum topic long-press menu (added by this fork) |
| Hide a PSA row | `ChatList_HideAction` on the PSA row (added by this fork) |
| Edit a custom list entry | `Chat_InlineTopicMenu_Edit` |

Two actions upstream exposed *only* through a swipe are mirrored in the
long-press menu by this fork: hiding/unhiding the General topic of a forum, and
hiding a sponsored (PSA) row. Both use the same rights checks and the same engine
calls as the swipe did.

Accessibility: the VoiceOver custom actions for a chat row are untouched, so the
full action set remains available to assistive technology.

Rows that belong to embedded management lists (quick replies, business message
lists, command lists, the personal channel) are **not** the chat list. Upstream
offers their edit/delete only through this swipe, so they keep it.

## 2. No side topics panel inside forums

Inside a forum/monoforum topic, upstream can show a vertical topics strip on the
left edge (92 pt) when the "sidebar" panel mode is selected. Telegram Plus never
shows it: the left space is given to the forum/topic interface instead.

The `.side` presentation state is coerced to `.top` when decoded, and `.side` is
removed from the panel toggle cycle, so the side layout cannot be entered at all.
Topics remain fully reachable through the standard top/bottom topics header
panel, which stays available and toggleable exactly as upstream. Normal chats and
the regular chat list outside forums are unaffected.

## 3. Log in by QR Code on the phone entry screen

Upstream ships this flow but gates its only entry point behind a debug-only tap
gesture, so it is unreachable in a release build. This fork puts a real "Log in
by QR Code" button on the phone entry screen.

Tapping it exports a login token (`auth.exportLoginToken`) and renders it as a QR
code that refreshes itself until it is used or expires. Scanning that code from
an already-authorised Telegram device approves the login, which is the same
two-sided flow upstream implements — only the entry point was added.

On the authorised side, the confirmation screen (Settings → Devices) also accepts
a code picked from the photo library, not only a live camera frame: a login token
decoded from an image is approved directly instead of being resolved as a `t.me`
link.

## 4. Signup captcha on a re-signed build

A sideloaded build keeps its own bundle identifier. Google's reCAPTCHA Enterprise
SDK identifies the calling app through `NSBundle.bundleIdentifier` and refuses to
run for an identifier that is not registered for the site key Telegram's server
supplied, failing with `Invalid Package Name`. The captcha therefore never
renders and the authorization request stalls until its 20 s timeout reports a
network problem.

This fork presents the registered bundle identifier for the duration of the SDK
call only. **This is not a bypass:** the user still has to solve the captcha and
the server still validates the result. It is corrected back to the real
identifier once the call returns.

## 5. Diagnostics: app logs in the Files app

The auth screens write a structured log, but on a device installed without a Mac
there is no way to read it. This fork mirrors the app's own log files into
`Documents/TelegramPlus-Logs` and enables `UIFileSharingEnabled`, so the log can
be opened in the Files app.

The mirror is refreshed on a 5 s timer rather than once at launch, and
`diagnostics-info.txt` records the bundle id, version, build, app group and a
`mirroredAt` timestamp — a launch-only snapshot is useless for the case it exists
for, a tap that produced no visible reaction.

Failure paths that used to be dropped silently are logged rather than swallowed:
the QR token export signal reports its error instead of returning nothing.

## Branding and identity

- Bundle id `ph.telegra.TelegramPlus`, so it installs alongside official Telegram.
- Display name `Telegram Plus`.
- App icon uses the black/Graphite gradient ("BlackFilled") look with the plane
  mark — deliberately not Telegram's white-plane-in-a-blue-circle logo, per
  Telegram's branding requirements for third-party clients.

## Building

Builds run on GitHub Actions via `.github/workflows/build-telegram-plus.yml`
(macOS runner, Bazel). The workflow provisions `build-system/fake-codesigning`,
regenerates the fake profiles for the fork's bundle id
(`build-system/Make/RegenerateProfilesForBundle.py`) and builds with
`build-system/telegram-plus-configuration.json`.

Resulting `.ipa` is unsigned; sideload it with SideStore / AltStore / Feather.

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

# URL schemes

Source of truth: the `plist_fragment(name = "UrlTypesInfoPlist")` in `Telegram/BUILD`. The Bazel build takes the schemes from there - `Info.plist`, `InfoBazel.plist` and `APP_SPECIFIC_URL_SCHEME` do not affect the product.

| scheme | reaches Telegram Plus? |
| --- | --- |
| `tgplus` | **yes, always** |
| `tg` | not reliably - the official app registers it too |
| `telegram`, `ton` | no (legacy / TON) |
| `tonsite` | no - routed into the web/TON branch |

Address the fork with its own scheme:

```
tgplus://privatepost?channel=<channel_id>&post=<message_id>
tgplus://privatepost?channel=<channel_id>&thread=<thread_id>&post=<message_id>
```

`tgplus://privatepost?channel=3911407661&post=23236` opens that message: the handler converts it to `t.me/c/<channel>/<post>` (`OpenUrl.swift`, `case "privatepost"`). Every host that works under `tg://` works under `tgplus://`; the gates in `OpenUrl.swift` and `AppDelegate.swift` accept `tg`, `tgplus` and the configured app-specific scheme. Inner host parsers that still match `tg` only (`UrlHandling.swift`, `OpenUrl.swift` ~line 114) handle other hosts and do not affect `privatepost`.

Verify a built IPA:

```
unzip -p TelegramPlus.ipa Payload/Telegram.app/Info.plist | plutil -p - | grep -A4 CFBundleURLSchemes
```
