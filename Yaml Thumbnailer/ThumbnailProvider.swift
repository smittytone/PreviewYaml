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

    // MARK:- Public Properties

    // Add key required values to self
    var doShowTag: Bool = true


    // MARK:- Private Properties

    // FROM 1.0.1
    private let appSuiteName: String = MNU_SECRETS.PID + BUFFOON_CONSTANTS.SUITE_NAME
    
    // FROM 1.1.0
    // Add Errors the may be returned by autoreleasepool closure
    private enum ThumbnailerError: Error {
        case badFileLoad(String)
        case badFileUnreadable(String)
        case badGfxBitmap
        case badGfxDraw
    }



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
        
        // FROM 1.1.0
        // Pull in 'self' values to save including them in closures
        let showTag = self.doShowTag
        
        // Set the thumbnail frame
        // NOTE This is always square, with height matched to width, so adjust
        //      to a 3:4 aspect ratio to maintain the macOS standard doc icon width
        let targetWidth: CGFloat = CGFloat(BUFFOON_CONSTANTS.THUMBNAIL_SIZE.ASPECT) * request.maximumSize.height
        let targetHeight: CGFloat = request.maximumSize.height
        let thumbnailFrame: CGRect = NSMakeRect(0.0,
                                                0.0,
                                                targetWidth,
                                                targetHeight)

        handler(QLThumbnailReply.init(contextSize: thumbnailFrame.size) { () -> Bool in
            // Place all the remaining code within the closure passed to 'handler()'
            let result: Result<Bool, ThumbnailerError> = autoreleasepool { () -> Result<Bool, ThumbnailerError> in
                // Load the source file using a co-ordinator as we don't know what thread this function
                // will be executed in when it's called by macOS' QuickLook code
                if FileManager.default.isReadableFile(atPath: request.fileURL.path) {
                    // Only proceed if the file is accessible from here
                    do {
                        // Get the file contents as a string, making sure it's not cached
                        // as we're not going to read it again any time soon
                        let data: Data = try Data.init(contentsOf: request.fileURL, options: [.uncached])
                        guard let yamlFileString: String = String.init(data: data, encoding: .utf8) else {
                            return .failure(ThumbnailerError.badFileLoad(request.fileURL.path))
                        }

                        // Get the Attributed String
                        let yamlAttString: NSAttributedString = getAttributedString(yamlFileString, true)

                        // Set the primary drawing frame and a base font size
                        let yamlFrame: CGRect = CGRect.init(x: BUFFOON_CONSTANTS.THUMBNAIL_SIZE.ORIGIN_X,
                                                            y: BUFFOON_CONSTANTS.THUMBNAIL_SIZE.ORIGIN_Y,
                                                            width: BUFFOON_CONSTANTS.THUMBNAIL_SIZE.WIDTH,
                                                            height: BUFFOON_CONSTANTS.THUMBNAIL_SIZE.HEIGHT)

                        // FROM 1.0.1
                        // Instantiate an NSTextField to display the NSAttributedString render of the YAML,
                        // and extend the size of its frame
                        let yamlTextField: NSTextField = NSTextField.init(labelWithAttributedString: yamlAttString)
                        yamlTextField.frame = yamlFrame
                        
                        // Generate the bitmap from the rendered YAML text view
                        guard let imageRep: NSBitmapImageRep = yamlTextField.bitmapImageRepForCachingDisplay(in: yamlFrame) else {
                            return .failure(ThumbnailerError.badGfxBitmap)
                        }

                        // Draw into the bitmap first the YAML view...
                        yamlTextField.cacheDisplay(in: yamlFrame, to: imageRep)

                        // Also generate text for the bottom-of-thumbnail file type tag,
                        // if the user has this set as a preference
                        if showTag {
                            // Define the frame of the tag area
                            let tagFrame: CGRect = CGRect.init(x: BUFFOON_CONSTANTS.THUMBNAIL_SIZE.ORIGIN_X,
                                                               y: BUFFOON_CONSTANTS.THUMBNAIL_SIZE.ORIGIN_Y,
                                                               width: BUFFOON_CONSTANTS.THUMBNAIL_SIZE.WIDTH,
                                                               height: BUFFOON_CONSTANTS.THUMBNAIL_SIZE.TAG_HEIGHT)
                            
                            // Set the paragraph style we'll use -- just centred text
                            let style: NSMutableParagraphStyle = NSMutableParagraphStyle.init()
                            style.alignment = .center

                            // Build the tag's string attributes
                            let tagAtts: [NSAttributedString.Key: Any] = [
                                .paragraphStyle: style as NSParagraphStyle,
                                .font: NSFont.systemFont(ofSize: CGFloat(BUFFOON_CONSTANTS.TAG_TEXT_SIZE)),
                                .foregroundColor: NSColor.init(red: 0.00, green: 0.49, blue: 0.47, alpha: 1.0)
                            ]

                            // FROM 1.0.1
                            // Instantiate an NSTextField to display the NSAttributedString render of the YAML,
                            // and extend the size of its frame
                            let tag: NSAttributedString = NSAttributedString.init(string: "YAML", attributes: tagAtts)
                            let tagTextField: NSTextField = NSTextField.init(labelWithAttributedString: tag)
                            tagTextField.frame = tagFrame
                            tagTextField.cacheDisplay(in: tagFrame, to: imageRep)
                        }

                        // Draw the bitmap into the current context
                        let drawResult = imageRep.draw(in: thumbnailFrame)
                        if drawResult {
                            return .success(true)
                        } else {
                            return .failure(ThumbnailerError.badGfxDraw)
                        }
                    } catch {
                        // NOP: fall through to error
                    }
                }

                // We didn't draw anything because of 'can't find file' error
                // NOTE Technically we should call 'handler(nil, error)'
                return .failure(ThumbnailerError.badFileUnreadable(request.fileURL.path))
            }

            // FROM 1.1.0
            // Pass the outcome up from out of the autorelease pool code
            // to the handler as a bool, logging an error if appropriate
            switch result {
                case .success(_):
                    return true
                case .failure(let error):
                    switch error {
                        case .badFileUnreadable(let filePath):
                            NSLog("Could not access file \(filePath)")
                        case .badFileLoad(let filePath):
                            NSLog("Could not render file \(filePath)")
                        default:
                            NSLog("Could not render thumbnail")
                    }
            }

            return false
        }, nil)
    }

}
