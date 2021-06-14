/*
 *  ThumbnailProvider.swift
 *  PreviewYaml
 *
 *  Created by Tony Smith on 22/04/2021.
 *  Copyright © 2021 Tony Smith. All rights reserved.
 */


import QuickLookThumbnailing
import Cocoa


class ThumbnailProvider: QLThumbnailProvider {

    // MARK: Public Properties
    
    // NOTE May remove some or all of these later
    // public var reportError: NSError? = nil
    var doShowTag: Bool = true
    
    
    // MARK: Private Properties
    
    // FROM 1.0.1
    private var appSuiteName: String = MNU_SECRETS.PID + BUFFOON_CONSTANTS.SUITE_NAME
    
    
    // MARK:- Lifecycle Required Functions
    
    override init() {
        
        /*
         * Override the init() function so that we can do crucial
         * setup in a thread-friendly way and avoid race conditions
         */
        
        // Must call the super class because we don't know
        // what operations it performs
        super.init()
        
        // Set the base values once per instantiation, not every
        // time a string is rendered (which risks a race condition)
        setBaseValues(true)
        
        // Get the preference for showing a tag and do it once so it 
        // only ever needs to be read from the property from this point on
        if let defaults = UserDefaults(suiteName: self.appSuiteName) {
            defaults.synchronize()
            self.doShowTag = defaults.bool(forKey: "com-bps-previewyaml-do-show-tag")
        }
    }

    
    // MARK:- QLThumbnailProvider Required Functions

    override func provideThumbnail(for request: QLFileThumbnailRequest, _ handler: @escaping (QLThumbnailReply?, Error?) -> Void) {
        
        /*
         * This is the main entry point for the macOS thumbnailing system
         */
        
        // Set the thumbnail frame
        // NOTE This is always square, with height matched to width, so adjust
        //      to a 3:4 aspect ratio to maintain the macOS standard doc icon width
        let thumbnailFrame: CGRect = NSMakeRect(0.0,
                                                0.0,
                                                CGFloat(BUFFOON_CONSTANTS.THUMBNAIL_SIZE.ASPECT) * request.maximumSize.height,
                                                request.maximumSize.height)
        
        handler(QLThumbnailReply.init(contextSize: thumbnailFrame.size) { () -> Bool in
            // Place all the remaining code within the closure passed to 'handler()'
            let success = autoreleasepool { () -> Bool in
                // Load the source file using a co-ordinator as we don't know what thread this function
                // will be executed in when it's called by macOS' QuickLook code
                if FileManager.default.isReadableFile(atPath: request.fileURL.path) {
                    // Only proceed if the file is accessible from here
                    do {
                        // Get the file contents as a string, making sure it's not cached
                        // as we're not going to read it again any time soon
                        let data: Data = try Data.init(contentsOf: request.fileURL, options: [.uncached])
                        guard let yamlFileString: String = String.init(data: data, encoding: .utf8) else { return false }
                            
                        // Get the Attributed String
                        let yamlAttString: NSAttributedString = getAttributedString(yamlFileString, true)

                        // Set the primary drawing frame and a base font size
                        let yamlFrame: CGRect = CGRect.init(x: BUFFOON_CONSTANTS.THUMBNAIL_SIZE.ORIGIN_X,
                                                            y: BUFFOON_CONSTANTS.THUMBNAIL_SIZE.ORIGIN_Y,
                                                            width: BUFFOON_CONSTANTS.THUMBNAIL_SIZE.WIDTH,
                                                            height: BUFFOON_CONSTANTS.THUMBNAIL_SIZE.HEIGHT)

                        /*
                        // Instantiate an NSTextView to display the NSAttributedString render of the YAML
                        // Make sure it is not selectable, ie. not interactive
                        let yamlTextView: NSTextView = NSTextView.init(frame: yamlFrame)
                        yamlTextView.isSelectable = false
                        yamlTextView.backgroundColor = NSColor.white

                        // Write the YAML NSAttributedString into the view's text storage
                        guard let yamlTextStorage: NSTextStorage = yamlTextView.textStorage else { return false }
                        yamlTextStorage.beginEditing()
                        yamlTextStorage.setAttributedString(yamlAttString)
                        yamlTextStorage.endEditing()
                        */

                        // FROM 1.0.1
                        // Instantiate an NSTextField to display the NSAttributedString render of the YAML,
                        // and extend the size of its frame
                        let yamlTextField: NSTextField = NSTextField.init(labelWithAttributedString: yamlAttString)
                        yamlTextField.frame = yamlFrame

                        // Also generate text for the bottom-of-thumbnail file type tag,
                        // if the user has this set as a preference
                        // FROM 1.3.1 -- implement tag as NSTextField label
                        var tagTextField: NSTextField? = nil
                        var tagFrame: CGRect? = nil

                        if self.doShowTag {
                            // Define the frame of the tag area
                            tagFrame = CGRect.init(x: BUFFOON_CONSTANTS.THUMBNAIL_SIZE.ORIGIN_X,
                                                   y: BUFFOON_CONSTANTS.THUMBNAIL_SIZE.ORIGIN_Y,
                                                   width: BUFFOON_CONSTANTS.THUMBNAIL_SIZE.WIDTH,
                                                   height: BUFFOON_CONSTANTS.THUMBNAIL_SIZE.TAG_HEIGHT)

                            /*
                            // Instantiate an NSTextView to display the NSAttributedString render of the tag,
                            // this time with a clear background
                            // Make sure it is not selectable, ie. not interactive
                            // NOTE 'tagTextView' is an optional
                            tagTextView = NSTextView.init(frame: tagFrame!)
                            tagTextView!.isSelectable = false
                            tagTextView!.backgroundColor = NSColor.clear

                            // Write the tag rendered as an NSAttributedString into the view's text storage
                            if let tagTextStorage: NSTextStorage = tagTextView!.textStorage {
                                // NOTE We use 'request.maximumSize' for more accurate results
                                tagTextStorage.beginEditing()
                                tagTextStorage.setAttributedString(self.getTagString("YAML", request.maximumSize.width))
                                tagTextStorage.endEditing()
                            } else {
                                // Set this on error so we don't try and draw the tag later
                                tagFrame = nil
                            }
                            */

                            // FROM 1.0.1
                            // Instantiate an NSTextField to display the NSAttributedString render of the YAML,
                            // and extend the size of its frame
                            tagTextField = NSTextField.init(labelWithAttributedString: self.getTagString("YAML", request.maximumSize.width))
                            tagTextField!.frame = tagFrame!
                        }

                        // Generate the bitmap from the rendered YAML text view
                        guard let imageRep: NSBitmapImageRep = yamlTextField.bitmapImageRepForCachingDisplay(in: yamlFrame) else { return false }
                        
                        // Draw into the bitmap first the YAML view...
                        yamlTextField.cacheDisplay(in: yamlFrame, to: imageRep)

                        // ...then the tag view
                        if tagFrame != nil && tagTextField != nil {
                            tagTextField!.cacheDisplay(in: tagFrame!, to: imageRep)
                        }

                        return imageRep.draw(in: thumbnailFrame)
                    } catch {
                        // NOP: fall through to error
                    }
                }

                // We didn't draw anything because of an error
                // NOTE Technically we should call 'handler(nil, error)'
                return false
            }

            // Pass the outcome up from out of the autorelease
            // pool code to the handler
            return success
        }, nil)
    }

    
    // MARK:- Misc Functions
    
    func getTagString(_ tag: String, _ width: CGFloat) -> NSAttributedString {

        /*
         * Set the text for the bottom-of-thumbnail file type tag
         */

        // Set the paragraph style we'll use -- just centred text
        let style: NSMutableParagraphStyle = NSMutableParagraphStyle.init()
        style.alignment = .center
        
        // Build the tag's string attributes
        let tagAtts: [NSAttributedString.Key: Any] = [
            .paragraphStyle: style as NSParagraphStyle,
            .font: NSFont.systemFont(ofSize: CGFloat(BUFFOON_CONSTANTS.TAG_TEXT_SIZE)),
            .foregroundColor: NSColor.init(red: 0.00, green: 0.49, blue: 0.47, alpha: 1.0)
        ]

        // Return the attributed string built from the tag
        return NSAttributedString.init(string: tag, attributes: tagAtts)
    }

}
