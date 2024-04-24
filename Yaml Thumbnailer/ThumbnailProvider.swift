/*
 *  ThumbnailProvider.swift
 *  PreviewYaml
 *
 *  Created by Tony Smith on 22/04/2021.
 *  Copyright © 2024 Tony Smith. All rights reserved.
 */


import QuickLookThumbnailing
import Cocoa


class ThumbnailProvider: QLThumbnailProvider {

    // MARK:- Private Properties
    
    // FROM 1.1.0
    // Add Errors the may be returned by autoreleasepool closure
    private enum ThumbnailerError: Error {
        case badFileLoad(String)
        case badFileUnreadable(String)
        case badGfxBitmap
        case badGfxDraw
    }


    // MARK:- QLThumbnailProvider Required Functions

    override func provideThumbnail(for request: QLFileThumbnailRequest, _ handler: @escaping (QLThumbnailReply?, Error?) -> Void) {

        /*
         * This is the main entry point for the macOS thumbnailing system
         */
        
        // Set the thumbnail frame
        // NOTE This is always square, with height matched to width, so adjust
        //      to a 3:4 aspect ratio to maintain the macOS standard doc icon width
        let iconScale: CGFloat = request.scale
        let thumbnailFrame: CGRect = NSMakeRect(0.0,
                                                0.0,
                                                CGFloat(BUFFOON_CONSTANTS.THUMBNAIL_SIZE.ASPECT) * request.maximumSize.height,
                                                request.maximumSize.height)
        
        handler(QLThumbnailReply.init(contextSize: thumbnailFrame.size) { (context) -> Bool in
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
                        
                        // FROM 1.1.2
                        // Get the string's encoding, or fail back to .utf8
                        let encoding: String.Encoding = data.stringEncoding ?? .utf8
                        
                        guard let yamlFileString: String = String.init(data: data, encoding: encoding) else {
                            return .failure(ThumbnailerError.badFileLoad(request.fileURL.path))
                        }
                        
                        // Instatiate the common code
                        let common: Common = Common.init(true)

                        // Get the Attributed String
                        let yamlAtts: NSAttributedString = common.getAttributedString(yamlFileString)

                        // Set the primary drawing frame and a base font size
                        let yamlFrame: CGRect = NSMakeRect(CGFloat(BUFFOON_CONSTANTS.THUMBNAIL_SIZE.ORIGIN_X),
                                                           CGFloat(BUFFOON_CONSTANTS.THUMBNAIL_SIZE.ORIGIN_Y),
                                                           CGFloat(BUFFOON_CONSTANTS.THUMBNAIL_SIZE.WIDTH),
                                                           CGFloat(BUFFOON_CONSTANTS.THUMBNAIL_SIZE.HEIGHT))

                        // FROM 1.0.1
                        // Instantiate an NSTextField to display the NSAttributedString render of the YAML,
                        // and extend the size of its frame
                        let yamlTextField: NSTextField = NSTextField.init(labelWithAttributedString: yamlAtts)
                        yamlTextField.frame = yamlFrame
                        
                        // Generate the bitmap from the rendered YAML text view
                        guard let bodyImageRep: NSBitmapImageRep = yamlTextField.bitmapImageRepForCachingDisplay(in: yamlFrame) else {
                            return .failure(ThumbnailerError.badGfxBitmap)
                        }

                        // Draw into the bitmap first the YAML view...
                        yamlTextField.cacheDisplay(in: yamlFrame, to: bodyImageRep)

                        // Also generate text for the bottom-of-thumbnail file type tag,
                        // if the user has this set as a preference
                        var tagImageRep: NSBitmapImageRep? = nil
                        
                        // FROM 1.1.2
                        // Add a Finder tag based on OS version
                        let sysVer: OperatingSystemVersion = ProcessInfo.processInfo.operatingSystemVersion
                        if sysVer.majorVersion < 12 && common.doShowTag {
                            // Define the frame of the tag area
                            let tagFrame: CGRect = NSMakeRect(CGFloat(BUFFOON_CONSTANTS.THUMBNAIL_SIZE.ORIGIN_X),
                                                              CGFloat(BUFFOON_CONSTANTS.THUMBNAIL_SIZE.ORIGIN_Y),
                                                              CGFloat(BUFFOON_CONSTANTS.THUMBNAIL_SIZE.WIDTH),
                                                              CGFloat(BUFFOON_CONSTANTS.THUMBNAIL_SIZE.TAG_HEIGHT))
                            
                            // Set the paragraph style we'll use -- just centred text
                            let style: NSMutableParagraphStyle = NSMutableParagraphStyle.init()
                            style.alignment = .center

                            // Build the tag's string attributes
                            let tagAtts: [NSAttributedString.Key: Any] = [
                                .paragraphStyle: style,
                                .font: NSFont.systemFont(ofSize: CGFloat(BUFFOON_CONSTANTS.TAG_TEXT_SIZE)),
                                .foregroundColor: NSColor.init(red: 0.00, green: 0.49, blue: 0.47, alpha: 1.0)
                            ]

                            // FROM 1.0.1
                            // Instantiate an NSTextField to display the NSAttributedString render of the YAML,
                            // and extend the size of its frame
                            let tag: NSAttributedString = NSAttributedString.init(string: "YAML", attributes: tagAtts)
                            let tagTextField: NSTextField = NSTextField.init(labelWithAttributedString: tag)
                            tagTextField.frame = tagFrame
                            
                            // Draw the view into the bitmap
                            if let imageRep: NSBitmapImageRep = tagTextField.bitmapImageRepForCachingDisplay(in: tagFrame) {
                                tagTextField.cacheDisplay(in: tagFrame, to: imageRep)
                                tagImageRep = imageRep
                            }
                        }

                        // Alternative drawing code to make use of a supplied context,
                        // scaling as required (retina vs non-retina screen)
                        // NOTE 'context' passed in by the caller, ie. macOS QL server
                        var drawResult: Bool = false
                        var scaleFrame: CGRect = NSMakeRect(0.0,
                                                            0.0,
                                                            thumbnailFrame.width * iconScale,
                                                            thumbnailFrame.height * iconScale)
                        if let image: CGImage = bodyImageRep.cgImage {
                            context.draw(image, in: scaleFrame, byTiling: false)
                            drawResult = true
                        }
                        
                        // Add the tag
                        if let image: CGImage = tagImageRep?.cgImage {
                            scaleFrame = NSMakeRect(0.0,
                                                    0.0,
                                                    thumbnailFrame.width * iconScale,
                                                    thumbnailFrame.height * iconScale * 0.2)
                            context.draw(image, in: scaleFrame, byTiling: false)
                        }

                        // Required to prevent 'thread ended before CA actions committed' errors in log
                        CATransaction.commit()
                        
                        if drawResult {
                            return .success(true)
                        } else {
                            return .failure(ThumbnailerError.badGfxDraw)
                        }
                        
                        // return drawResult
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
