/*
 *  PreviewViewController.swift
 *  PreviewYaml
 *
 *  Created by Tony Smith on 22/04/2021.
 *  Copyright © 2021 Tony Smith. All rights reserved.
 */

import Cocoa
import Quartz


class PreviewViewController: NSViewController,
                             QLPreviewingController {
    
    // MARK:- Class Properties

    @IBOutlet var renderTextView: NSTextView!
    @IBOutlet var renderTextScrollView: NSScrollView!

    override var nibName: NSNib.Name? {
        return NSNib.Name("PreviewViewController")
    }

    
    // MARK:- QLPreviewingController Required Functions

    func preparePreviewOfFile(at url: URL, completionHandler handler: @escaping (Error?) -> Void) {

        // Get an error message ready for use
        var reportError: NSError? = nil

        // Load the source file using a co-ordinator as we don't know what thread this function
        // will be executed in when it's called by macOS' QuickLook code
        if FileManager.default.isReadableFile(atPath: url.path) {
            // Only proceed if the file is accessible from here
            do {
                // Get the file contents as a string
                let data: Data = try Data.init(contentsOf: url)
                if let yamlFileString: String = String.init(data: data, encoding: .utf8) {
                    // Get the key string first
                    let yamlAttString: NSAttributedString = getAttributedString(yamlFileString, false)
                    
                    // Update the NSTextView
                    var doShowLightBackground: Bool = false

                    if let defaults = UserDefaults(suiteName: MNU_SECRETS.PID + ".suite.preview-yaml") {
                        defaults.synchronize()
                        doShowLightBackground = defaults.bool(forKey: "com-bps-previewyaml-do-use-light")
                    }
                    
                    // Knock back the light background to make the scroll bars visible in dark mode
                    // NOTE If !doShowLightBackground,
                    //              in light mode, the scrollers show up dark-on-light, in dark mode light-on-dark
                    //      If doShowLightBackground,
                    //              in light mode, the scrollers show up light-on-light, in dark mode light-on-dark
                    // NOTE Changing the scrollview scroller knob style has no effect
                    self.renderTextView.backgroundColor = doShowLightBackground ? NSColor.init(white: 1.0, alpha: 0.9) : NSColor.textBackgroundColor
                    
                    self.renderTextScrollView.scrollerKnobStyle = doShowLightBackground ? .dark : .light

                    if let renderTextStorage: NSTextStorage = self.renderTextView.textStorage {
                        /*
                         * NSTextStorage subclasses that return true from the fixesAttributesLazily
                         * method should avoid directly calling fixAttributes(in:) or else bracket
                         * such calls with beginEditing() and endEditing() messages.
                         */
                        renderTextStorage.beginEditing()
                        renderTextStorage.setAttributedString(yamlAttString)
                        renderTextStorage.endEditing()
                    }
                    
                    // Add the subview to the instance's own view and draw
                    self.view.display()

                    // Call the QLPreviewingController indicating no error
                    // (argument is nil)
                    handler(nil)
                    return
                } else {
                    // We couldn't get the markdwn string so set an appropriate error to report back
                    reportError = NSError(domain: "com.bps.PreviewYaml.Yaml-Previewer",
                                          code: BUFFOON_CONSTANTS.ERRORS.CODES.BAD_MD_STRING,
                                          userInfo: [NSLocalizedDescriptionKey: BUFFOON_CONSTANTS.ERRORS.MESSAGES.BAD_MD_STRING])
                }
            } catch {
                // We couldn't read the file so set an appropriate error to report back
                reportError = NSError(domain: "com.bps.PreviewYaml.Yaml-Previewer",
                                      code: BUFFOON_CONSTANTS.ERRORS.CODES.FILE_WONT_OPEN,
                                      userInfo: [NSLocalizedDescriptionKey: BUFFOON_CONSTANTS.ERRORS.MESSAGES.FILE_WONT_OPEN])
            }
        } else {
            // We couldn't access the file so set an appropriate error to report back
            reportError = NSError(domain: "com.bps.PreviewYaml.Yaml-Previewer",
                                  code: BUFFOON_CONSTANTS.ERRORS.CODES.FILE_INACCESSIBLE,
                                  userInfo: [NSLocalizedDescriptionKey: BUFFOON_CONSTANTS.ERRORS.MESSAGES.FILE_INACCESSIBLE])
        }

        // Call the QLPreviewingController indicating an error
        // (argumnet is not nil)
        handler(reportError)
    }


    func preparePreviewOfSearchableItem(identifier: String, queryString: String?, completionHandler handler: @escaping (Error?) -> Void) {

        // Is this ever called?
        NSLog("BUFFOON searchable identifier: \(identifier)")
        NSLog("BUFFOON searchable query:      " + (queryString ?? "nil"))

        // Hand control back to QuickLook
        handler(nil)
    }

}
