# PreviewYaml 1.2.2 #

App Extension-based macOS QuickLook previews and Finder thumbnails for [YAML](https://yaml.org) files.

![PreviewYaml App Store QR code](qr-code-py.jpg)

## Installation and Usage ##

Just *run* the host app once to register the extensions &mdash; you can quit the app as soon as it has launched. We recommend logging out of your Mac and back in again at this point. Now you can preview YAML documents using QuickLook (select an icon and hit Space), and Finder’s preview pane and **Info** panels.

You can disable and re-enable the Yaml Previewer and Yaml Thumbnailer extensions at any time in **System Preferences > Extensions > Quick Look**.

### Adjusting the Preview ###

You can alter some of the key elements of the preview by using the **Preferences** panel:

- The colour of keys, strings and special values (`NaN, `±INF`) can selected using the macOS colour picker.
- The preview’s font, which you can now choose from all the monospace fonts installed on your system.
- The preview’s font style, eg. regular, bold, italic etc.
- The preview’s text size, from 10pt to 28pt.
- Level of indentation: 1, 2, 4 or 8 spaces.
- Whether mappings should be sorted alphabetically by key value.
- Whether mapping keys should be suffixed with the YAML colon marker.
- Whether preview should be display white-on-black even in macOS’ Dark Mode.

Changing these settings will affect previews immediately, but may not affect thumbnails until you open a folder that has not been previously opened in the current login session, you edit a thumbnail, or you log back into your Mac account.

## Troubleshooting ##

If PreviewYaml reports that it was unable to render YAML, this is almost certainly caused by a slight malformation of the YAML itself — the error message should help you spot the problem. PreviewYaml’s YAML library is quite strict, so YAML malformations which other apps may accept may be rejected by PreviewYaml. For this reason, you can optionally tell PreviewYaml to display a file’s raw YAML in the event of a parsing error. This option is chosen in PreviewYaml’s **Preferences** panel and will allow you to QuickLook YAML files, albeit without rendering.

## Known Issues ##

* *PreviewYaml* currently expects files to be encoded in UTF-8.
* YAML custom tags are not as yet correctly rendered by *PreviewYAML*’s YAML library.

Comments are not rendered.

## Source Code ##

This repository contains the primary source code for *PreviewYaml*. Certain graphical assets, code components and data files are not included. To build *PreviewYaml* from scratch, you will need to add these files yourself or remove them from your fork.

The files `REPLACE_WITH_YOUR_FUNCTIONS` and `REPLACE_WITH_YOUR_CODES` must be replaced with your own files. The former will contain your `sendFeedback(_ feedback: String) -> URLSessionTask?` function. The latter your Developer Team ID, used as the App Suite identifier prefix.

You will need to generate your own `Assets.xcassets` file containing the app icon and an `app_logo.png` file.

You will need to create your own `new` directory containing your own `new.html` file.

## Contributions ##

Contributions are welcome, but pull requestss can only be accepted when they target the `develop` branch. PRs targetting `main` will be rejected.

Contributions will only be accepted if they code they contain is licensed under the terms of [the MIT Licence](#LICENSE.md)

## Release Notes ##

- 1.2.2 *Unreleased*
    - Correctly render the bad YAML separator line: revert NSTextViews to TextKit 1 (previously bumped to 2 by Xcode).
    - Improve preference change handling.
    - Fix out-of-bounds double-to-int conversion in Yaml library.
- 1.2.1 *5 May 2024*
    - Revise thumbnailer to improve memory utilization and efficiency.
    - Fix the 'white flash' seen on first presenting the What's New sheet.
- 1.2.0 *25 August 2023*
    - Make the alphabetical sorting of keys optional. Default: do sort. Requested by: klas.
    - Make the display of key colon symbols a setting. Default: do not show.
    - Allow users to choose the colours of strings and special values (`NaN`, `±INF`).
- 1.1.5 *14 February 2023*
    - Fix regression affecting thumbnails of large documents.
- 1.1.4 *21 January 2023*
    - Add link to [PreviewText](https://smittytone.net/previewtext/index.html).
    - Better menu handling when panels are visible.
    - Better app exit management.
    - Bug fixes.
- 1.1.3 *2 October 2022*
    - Add link to [PreviewJson](https://smittytone.net/previewjson/index.html).
- 1.1.2 *26 August 2022*
    - Initial support for non-utf8 source code file encodings.
- 1.1.1 *19 November 2021*
    - Disable selection of thumbnail tags under macOS 12 Monterey to avoid clash with system-added tags.
- 1.1.0 *28 July 2021*
    - Allow any installed monospace font to be selected.
    - Allow any font style to be applied.
    - Allow any key colour to be chosen using macOS’ colour picker.
    - Indent multi-line text.
    - Tighten thumbnail rendering code.
    - Fixed a rare bug in the previewer error reporting code.
    - Link to [PreviewCode](https://smittytone.net/previewcode/index.html).
- 1.0.1 *18 June 2021*
    - Add links to other PreviewApps.
    - Support macOS 11 Big Sur’s UTType API.
    - Stability improvements.
- 1.0.0 *10 May 2021*
    - Initial public release.

## Copyright and Licensing

PreviewYaml © 2024, Tony Smith (@smittytone). Contains YamlSwift © 2019 Behrang Noruzi Niya.

Source code only licensed under the [MIT Licence](LICENSE).
