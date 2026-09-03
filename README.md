# Jitouch

> **Unofficial community fork.** This repository is based on
> [JitouchApp/Jitouch](https://github.com/JitouchApp/Jitouch) and was modified
> by [kitjub](https://github.com/kitjub) in September 2026 to support Apple
> Silicon and current macOS releases. It is not an official release and is not
> endorsed by the original authors.

**Jitouch** is a Mac application that expands the set of multi-touch gestures for MacBook, Magic Mouse, and Magic Trackpad. These thoughtfully designed gestures enable users to perform frequent tasks more easily such as changing tabs in web browsers, closing windows, minimizing windows, changing spaces, and a lot more.

For more details, see https://www.jitouch.com/.

## Installation

### Personal Apple Silicon build for current macOS

This branch includes a nib-free, native arm64 menu-bar app that builds with
Apple Command Line Tools; full Xcode is not required.

```sh
make
make verify
make probe
make install
```

The final app is `build/Jitouch Modern.app`. The personal installer places it in
`~/Applications`, uses a separate modern LaunchAgent, stops (but does not delete)
the loaded legacy job, and preserves the existing preferences and Preference
Pane. See [BUILDING-CLT.md](BUILDING-CLT.md) for details.

### Legacy release

Download `Install-Jitouch.pkg` from the [releases](https://github.com/aaronkollasch/jitouch/releases/latest) page.
Double-click and follow the instructions to install.

## Troubleshooting

When opening the Jitouch preference pane for the first time, you may see an error message such as "Could not load Jitouch preference pane". If so, restarting your computer should fix this.

After opening the Jitouch preference pane in System Preferences, a prompt should appear to give Jitouch accessibility permissions. If the prompt doesn't appear, try switching Jitouch off and on in the Jitouch preference pane. Otherwise, you will need to manually give Jitouch permissions.

#### To manually give Jitouch permissions:
- Go to the folder `/Library/PreferencePanes/Jitouch.prefPane/Contents/Resources/` in Finder. If you installed Jitouch for your user only, replace `/Library` with `~/Library`. This folder should contain an application named Jitouch.app.
- Open System Preferences and go to "Security & Privacy -> Privacy -> Accessibility", which is a list labeled "Allow these apps to control your computer".
- Click the lock to make changes, then drag Jitouch.app from Finder into that list.
- Force restart Jitouch with `killall Jitouch` in the Terminal.

## How to build from source

1. Open jitouch/Jitouch/Jitouch.xcodeproj in Xcode and build the project. This will create Jitouch.app in the prefpane folder. For the highest performance, set the Build Configuration to Release.
2. Open prefpane/Jitouch.xcodeproj in Xcode and build the project. This will create Jitouch.prefPane.
3. Double-click Jitouch.prefPane to install Jitouch.

## License

Copyright (c) Supasorn Suwajanakorn and Sukolsak Sakshuwong. All rights reserved.  
Modified work copyright (c) Aaron Kollasch. All rights reserved.

Licensed under the [GNU General Public License v3.0](LICENSE).
