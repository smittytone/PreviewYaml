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

    // MARK: Properties
    
    // NOTE May remove some or all of these later
    // public var reportError: NSError? = nil
    var doShowTag: Bool = true
    
    
    // MARK:- Lifecycle Required Functions
    
    override init() {
        // Must call the super class because we don't know
        // what operations it performs
        super.init()
        
        // Set the base values once per instantiation, not every
        // time a string is rendered (which risks a race condition)
        setBaseValues(true)
        
        // Get the preference for showing a tag and do it once so it 
        // only ever needs to be read from the property from this point on
        if let defaults = UserDefaults(suiteName: MNU_SECRETS.PID + ".suite.previewmarkdown") {
            defaults.synchronize()
            self.doShowTag = defaults.bool(forKey: "com-bps-previewmarkdown-do-show-tag")
        }
    }

    
    // MARK:- QLThumbnailProvider Required Functions

    override func provideThumbnail(for request: QLFileThumbnailRequest, _ handler: @escaping (QLThumbnailReply?, Error?) -> Void) {
        
        // Run everything on the main thread
        DispatchQueue.main.async {
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

                            // Instantiate an NSTextView to display the NSAttributedString render of the markdown
                            // Make sure it is not selectable, ie. not interactive
                            let yamlTextView: NSTextView = NSTextView.init(frame: yamlFrame)
                            yamlTextView.isSelectable = false
                            yamlTextView.backgroundColor = NSColor.white

                            // Write the YAML NSAttributedString into the view's text storage
                            guard let yamlTextStorage: NSTextStorage = yamlTextView.textStorage else { return false }
                            yamlTextStorage.setAttributedString(yamlAttString)

                            // Also generate text for the bottom-of-thumbnail file type tag,
                            // if the user has this set as a preference
                            var tagTextView: NSTextView? = nil
                            var tagFrame: CGRect? = nil

                            if self.doShowTag {
                                // Define the frame of the tag area
                                tagFrame = CGRect.init(x: BUFFOON_CONSTANTS.THUMBNAIL_SIZE.ORIGIN_X,
                                                       y: BUFFOON_CONSTANTS.THUMBNAIL_SIZE.ORIGIN_Y,
                                                       width: BUFFOON_CONSTANTS.THUMBNAIL_SIZE.WIDTH,
                                                       height: BUFFOON_CONSTANTS.THUMBNAIL_SIZE.TAG_HEIGHT)

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
                                    tagTextStorage.setAttributedString(self.getTagString("YAML", request.maximumSize.width))
                                } else {
                                    // Set this on error so we don't try and draw the tag later
                                    tagFrame = nil
                                }
                            }

                            // Generate the bitmap from the rendered markdown text view
                            guard let imageRep: NSBitmapImageRep = yamlTextView.bitmapImageRepForCachingDisplay(in: yamlFrame) else { return false }
                            
                            // Draw into the bitmap first the markdown view...
                            yamlTextView.cacheDisplay(in: yamlFrame, to: imageRep)

                            // ...then the tag view
                            if tagFrame != nil && tagTextView != nil {
                                tagTextView!.cacheDisplay(in: tagFrame!, to: imageRep)
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
    }


    func getTagString(_ tag: String, _ width: CGFloat) -> NSAttributedString {

        // Set the text for the bottom-of-thumbnail file type tag

        // Set the paragraph style we'll use -- just centred text
        let style: NSMutableParagraphStyle = NSMutableParagraphStyle.init()
        style.alignment = .center

        // Build the tag's string attributes
        let tagAtts: [NSAttributedString.Key: Any] = [
            .paragraphStyle: style as NSParagraphStyle,
            .font: NSFont.systemFont(ofSize: 120.0),
            .foregroundColor: (width < 128
                                ? NSColor.init(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0)
                                : NSColor.init(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0))
        ]

        // Return the attributed string built from the tag
        return NSAttributedString.init(string: tag, attributes: tagAtts)
    }

}
