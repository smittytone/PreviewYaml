# PreviewYaml 1.0.0

App Extension-based macOS QuickLook previews and Finder thumbnails for [YAML](https://yaml.org) files.

## Installation and Usage ##

Just run the host app once to register the extensions &mdash; you can quit the app as soon as it has launched. We recommend logging out of your Mac and back in again at this point. Now you can preview YAML documents using QuickLook (select an icon and hit Space), and Finder’s preview pane and **Info** panels.

You can disable and re-enable the Yaml Previewer and Yaml Thumbnailer extensions at any time in **System Preferences > Extensions > Quick Look**.

### Adjusting the Preview ###

You can alter some of the key elements of the preview by using the **Preferences** panel:

- The colour of keys.
- The preview’s font.
- The preview’s text size.
- Whether preview should be display white-on-black even in macOS’ Dark Mode.

Changing these settings will affect previews immediately, but may not affect thumbnails until you open a folder that has not been previously opened in the current login session.

## Troubleshooting ##

If PreviewYaml reports that it was unable to render YAML, this is almost certainly caused by a slight malformation of YAML itself. Rogue comma after a float? That will cause PreviewYaml’s YAML parser to reject the entire file. However, please note the **Known Issues**, below.

## Known Issues ##

I am aware of an issue with YAML files that contain the `.inf`, `.-inf` and/or `.nan` values. This issue prevents these files from being rendered.

PreviewYaml expects files in UTF-8 only.

## Source Code ##

This repository contains the primary source code for PreviewYaml. Certain graphical assets and data files are not included, but are required to build the application. To build PreviewYaml from scratch, you will need to examine the source code and add these files yourself.

## Release Notes

* 1.0.0 *Unreleased*
    * Initial public release.

## Copyright and Licensing

PreviewYaml © 2021, Tony Smith (@smittytone). Contains YamlSwift © 2021 Behrang Noruzi Niya.

Source code only licensed under the [MIT Licence](LICENSE).
