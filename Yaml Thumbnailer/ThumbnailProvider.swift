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
                    return handler(nil, ThumbnailerError.badFileLoad(request.fileURL.path))
                }

                // Instatiate the common code
                let common: Common = Common.init(true)

                // Set the primary drawing frame and a base font size
                let yamlFrame: CGRect = NSMakeRect(CGFloat(BUFFOON_CONSTANTS.THUMBNAIL_SIZE.ORIGIN_X),
                                                   CGFloat(BUFFOON_CONSTANTS.THUMBNAIL_SIZE.ORIGIN_Y),
                                                   CGFloat(BUFFOON_CONSTANTS.THUMBNAIL_SIZE.WIDTH),
                                                   CGFloat(BUFFOON_CONSTANTS.THUMBNAIL_SIZE.HEIGHT))

                // FROM 1.0.1
                // Instantiate an NSTextField to display the NSAttributedString render of the YAML,
                // and extend the size of its frame
                let yamlTextField: NSTextField = NSTextField.init(frame: yamlFrame)
                yamlTextField.attributedStringValue = common.getAttributedString(yamlFileString)

                // Generate the bitmap from the rendered YAML text view
                guard let bodyImageRep: NSBitmapImageRep = yamlTextField.bitmapImageRepForCachingDisplay(in: yamlFrame) else {
                    return handler(nil, ThumbnailerError.badGfxBitmap)
                }

                // Draw into the bitmap first the YAML view...
                yamlTextField.cacheDisplay(in: yamlFrame, to: bodyImageRep)

                if let image: CGImage = bodyImageRep.cgImage {
                    if let cgImage: CGImage = image.copy() {
                        // Set the thumbnail frame
                        // NOTE This is always square, with height matched to width, so adjust
                        //      to a 3:4 aspect ratio to maintain the macOS standard doc icon width
                        let iconScale: CGFloat = request.scale
                        let thumbnailFrame: CGRect = NSMakeRect(0.0,
                                                                0.0,
                                                                CGFloat(BUFFOON_CONSTANTS.THUMBNAIL_SIZE.ASPECT) * request.maximumSize.height,
                                                                request.maximumSize.height)


                        let scaleFrame: CGRect = NSMakeRect(0.0,
                                                            0.0,
                                                            thumbnailFrame.width * iconScale,
                                                            thumbnailFrame.height * iconScale)

                        // Pass a QLThumbnailReply and no error to the supplied handler
                        handler(QLThumbnailReply.init(contextSize: thumbnailFrame.size) { (context) -> Bool in
                            // `scaleFrame` and `cgImage` are immutable
                            context.draw(cgImage, in: scaleFrame, byTiling: false)
                            return true
                        }, nil)
                        return
                    }
                }

                handler(nil, ThumbnailerError.badGfxDraw)
                return
            } catch {
                // NOP: fall through to error
            }
        }

        // We didn't draw anything because of 'can't find file' error
        handler(nil, ThumbnailerError.badFileUnreadable(request.fileURL.path))
    }
}
