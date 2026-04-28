# PreviewYaml 2.0.0 #

App Extension-based macOS QuickLook previews and Finder thumbnails for [YAML](https://yaml.org) files.

[![PreviewYaml App Store QR code](qr-code-py.jpg)](https://apps.apple.com/gb/app/previewyaml/id1564574724?mt=12)

## Installation and Usage ##

Just *run* the host app once to register the extensions &mdash; you can quit the app as soon as it has launched. We recommend logging out of your Mac and back in again at this point. Now you can preview YAML documents using QuickLook (select an icon and hit Space), and Finder’s preview pane and **Info** panels.

You can disable and re-enable the Yaml Previewer and Yaml Thumbnailer extensions at any time in **System Preferences > Extensions > Quick Look**.

### Adjusting the Preview ###

You can alter some of the key elements of the preview by using the **Preferences** panel:

- The colour of keys, strings, comments, YAML delimiters and special values (`NaN`, `±INF`, YAML directives) can selected using the macOS colour picker.
- The preview’s font, which you can now choose from all the fonts installed on your system.
- The preview’s font style, eg. regular, bold, italic, etc.
- The preview’s text size, from 10pt to 28pt.
- Level of indentation: small, medium, large or extra-large.
- Whether mapping keys should be suffixed with the YAML colon marker, and sequence items bulleted.
- Whether to display show light previews under macOS dark mode or dark previews under macOS light mode, or to match the mode).

Changing these settings will affect previews immediately, but may not affect thumbnails until you open a folder that has not been previously opened in the current login session, you edit a thumbnail, or you log back into your Mac account.

## Known Issues ##

## Source Code ##

This repository contains the primary source code for *PreviewYaml*. Certain graphical assets, code components and data files are not included. To build *PreviewYaml* from scratch, you will need to add these files yourself or remove them from your fork.

The files `REPLACE_WITH_YOUR_FUNCTIONS` and `REPLACE_WITH_YOUR_CODES` must be replaced with your own files. The former will contain your `sendFeedback(_ feedback: String) -> URLSessionTask?` function. The latter your Developer Team ID, used as the App Suite identifier prefix.

You will need to generate your own `Assets.xcassets` file containing the app icon and an `app_logo.png` file.

You will need to create your own `new` directory containing your own `new.html` file.

## Contributions ##

Contributions are welcome, but pull requestss can only be accepted when they target the `develop` branch. PRs targetting `main` will be rejected.

Contributions will only be accepted if they code they contain is licensed under the terms of [the MIT Licence](#LICENSE.md)

## Release Notes ##

See [CHANGELOG.md](./CHANGELOG.md)

## Copyright and Licensing

Primary app code and UI design © 2026, Tony Smith.

Source code only licensed under the [MIT Licence](LICENSE).
