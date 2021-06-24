# PreviewYaml 1.1.0

App Extension-based macOS QuickLook previews and Finder thumbnails for [YAML](https://yaml.org) files.

![PreviewYaml App Store QR code](qr-code-py.jpg)

## Installation and Usage ##

Just run the host app once to register the extensions &mdash; you can quit the app as soon as it has launched. We recommend logging out of your Mac and back in again at this point. Now you can preview YAML documents using QuickLook (select an icon and hit Space), and Finder’s preview pane and **Info** panels.

You can disable and re-enable the Yaml Previewer and Yaml Thumbnailer extensions at any time in **System Preferences > Extensions > Quick Look**.

### Adjusting the Preview ###

You can alter some of the key elements of the preview by using the **Preferences** panel:

- The colour of keys, selected using the macOS colour picker.
- The preview’s font, which you can now choose from all the monospace fonts installed on your system.
- The preview’s text size, from 10pt to 28pt.
- Level of indentation: 1, 2, 4 or 8 spaces.
- Whether preview should be display white-on-black even in macOS’ Dark Mode.

Changing these settings will affect previews immediately, but may not affect thumbnails until you open a folder that has not been previously opened in the current login session, you edit a thumbnail, or you log back into your Mac account.

## Troubleshooting ##

If PreviewYaml reports that it was unable to render YAML, this is almost certainly caused by a slight malformation of the YAML itself — the error message should help you spot the problem. PreviewYaml’s YAML library is quite strict, so YAML malformations which other apps may accept may be rejected by PreviewYaml. For this reason, you can optionally tell PreviewYaml to display a file’s raw YAML in the event of a parsing error. This option is chosen in PreviewYaml’s **Preferences** panel and will allow you to QuickLook YAML files, albeit without rendering.

## Known Issues ##

PreviewYaml currently expects files to be encoded in UTF-8.

Certain YAML features — custom tags — are not as yet correctly rendered by PreviewYAML’s YAML library.

A YAML file containing `.nan`, `.inf` and/or `-.inf` values will prevent PreviewYAML from rendering the file. This is under investigation.

## Source Code ##

This repository contains the primary source code for PreviewYaml. Certain graphical assets and data files are not included, but are required to build the application. To build PreviewYaml from scratch, you will need to examine the source code and add these files yourself.

## Release Notes

* 1.1.0 *Unreleased*
    * Allow any installed monospace font to be selected.
    * Allow any colour to be chosen using macOS’ colour picker.
    * Tighten thumbnail rendering code.
    * Link to [PreviewCode](https://smittytone.net/previewcode/index.html).
* 1.0.1 *18 June 2021*
    * Add links to other PreviewApps.
    * Support macOS 11 Big Sur’s UTType API.
    * Stability improvements.
* 1.0.0 *10 May 2021*
    * Initial public release.

## Copyright and Licensing

PreviewYaml © 2021, Tony Smith (@smittytone). Contains YamlSwift © 2021 Behrang Noruzi Niya.

Source code only licensed under the [MIT Licence](LICENSE).
