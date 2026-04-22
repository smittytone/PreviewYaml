/*
 *  PreviewViewController.swift
 *  PreviewYaml
 *
 *  Created by Tony Smith on 22/04/2021.
 *  Copyright © 2025 Tony Smith. All rights reserved.
 */


import Cocoa
import Quartz


class PreviewViewController: NSViewController,
                             QLPreviewingController {

    // MARK: - Class UI Properties

    @IBOutlet var renderTextView: NSTextView!
    @IBOutlet var renderTextScrollView: NSScrollView!


    // MARK: - Public Properties

    override var nibName: NSNib.Name? {
        return NSNib.Name("PreviewViewController")
    }


    // MARK: - QLPreviewingController Required Functions

    // FROM 2.0.0
    // Update to use Swift Concurrency
    func preparePreviewOfFile(at url: URL) async throws {

        /*
         * This is the main entry point for the macOS QuickLook previewing system
         */

        // Get an error message ready for use
        var reportError: NSError? = nil

        // Get the file contents as a string
        do {
            // Get the file contents as a string
            let data = try Data(contentsOf: url, options: [.uncached])
            let encoding = data.stringEncoding ?? .utf8

            // Convert the data to a string
            if let yaml = String.init(data: data, encoding: encoding) {
                /*
                 Instantiate the common code within the closure
                 */
                let common = Common(forThumbnail: false)

                /*
                 Attributed string acquisition
                 */
                let attributedYaml = await common.getAttributedString(yaml)

                /*
                 Window and mode configuration
                 */

                // FROM 2.0.0
                // Set the parent window's size
                setPreviewWindowSize(common.settings)

                // FROM 2.0.0
                // The force-light-mode-preview-in-dark-mode setting is now a general
                // preview-colours-should-be-opposite-the-mode setting.
                var renderPreviewLight = NSApplication.shared.inLightMode
                if common.settings.doReverseMode {
                    // Invert the colour scheme based on the current mode
                    renderPreviewLight = !renderPreviewLight
                }

                // Update the NSTextView
                self.renderTextView.backgroundColor = renderPreviewLight ? NSColor.white : NSColor.textBackgroundColor
                self.renderTextScrollView.scrollerKnobStyle = renderPreviewLight ? .dark : .light
                self.view.appearance = renderPreviewLight ? NSAppearance(named: .aqua) : NSAppearance(named: .darkAqua)

                // FROM 2.0.0
                // Add margin if required
                if common.settings.previewMarginWidth > 0.0 {
                    self.renderTextView.textContainerInset = NSSize(width: common.settings.previewMarginWidth,
                                                                    height: common.settings.previewMarginWidth)
                }

                /*
                 Attributed String Presentation
                 */
                if let renderTextStorage: NSTextStorage = self.renderTextView.textStorage {
                    /*
                     * NSTextStorage subclasses that return true from the fixesAttributesLazily
                     * method should avoid directly calling fixAttributes(in:) or else bracket
                     * such calls with beginEditing() and endEditing() messages.
                     */
                    renderTextStorage.beginEditing()
                    renderTextStorage.setAttributedString(attributedYaml)
                    renderTextStorage.endEditing()
                    return
                }

                // We can't access the preview NSTextView's NSTextStorage
                reportError = makeError(BUFFOON_CONSTANTS.ERRORS.CODES.BAD_TS_STRING)
            } else {
                // FROM 1.1.2
                // We couldn't convert to data to a valid encoding
                let errDesc: String = "\(BUFFOON_CONSTANTS.ERRORS.MESSAGES.BAD_TS_STRING) \(encoding)"
                reportError = NSError(domain: BUFFOON_CONSTANTS.APP_CODE_PREVIEWER,
                                      code: BUFFOON_CONSTANTS.ERRORS.CODES.BAD_MD_STRING,
                                      userInfo: [NSLocalizedDescriptionKey: errDesc])
            }
        } catch {
            // We couldn't read the file so set an appropriate error to report back
            reportError = makeError(BUFFOON_CONSTANTS.ERRORS.CODES.FILE_WONT_OPEN)
        }

        // Error
        throw reportError!
    }


    // MARK:- Utility Functions

    /**
     Generate an NSError for an internal error, specified by its code.

     Codes are listed in `Constants.swift`

     - Parameters:
     - code: The internal error code.

     - Returns: The described error as an NSError.
     */
    func makeError(_ code: Int) -> NSError {

        var errDesc: String

        switch(code) {
            case BUFFOON_CONSTANTS.ERRORS.CODES.FILE_INACCESSIBLE:
                errDesc = BUFFOON_CONSTANTS.ERRORS.MESSAGES.FILE_INACCESSIBLE
            case BUFFOON_CONSTANTS.ERRORS.CODES.FILE_WONT_OPEN:
                errDesc = BUFFOON_CONSTANTS.ERRORS.MESSAGES.FILE_WONT_OPEN
            case BUFFOON_CONSTANTS.ERRORS.CODES.BAD_TS_STRING:
                errDesc = BUFFOON_CONSTANTS.ERRORS.MESSAGES.BAD_TS_STRING
            case BUFFOON_CONSTANTS.ERRORS.CODES.BAD_MD_STRING:
                errDesc = BUFFOON_CONSTANTS.ERRORS.MESSAGES.BAD_MD_STRING
            default:
                errDesc = "UNKNOWN ERROR"
        }

        return NSError(domain: BUFFOON_CONSTANTS.APP_CODE_PREVIEWER,
                       code: code,
                       userInfo: [NSLocalizedDescriptionKey: errDesc])
    }


    /**
     Specify the content size of the parent view.
    */
    private func setPreviewWindowSize(_ settings: PYSettings) {

        var screen: NSScreen = NSScreen.screens[0]

        // We've set `screen` to the primary, ie. menubar-displaying,
        // screen, but ideally we should pick the screen with user focus.
        // They may be one and the same, of course...
        if let mainScreen = NSScreen.main, mainScreen != screen {
            screen = mainScreen
        }

        let height: CGFloat = screen.frame.size.height * settings.previewWindowScale
        let width: CGFloat = screen.frame.size.width * settings.previewWindowScale
        self.preferredContentSize = NSSize(width: width, height: height)
    }
}
