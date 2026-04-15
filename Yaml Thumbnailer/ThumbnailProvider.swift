/*
 *  ThumbnailProvider.swift
 *  PreviewYaml
 *
 *  Created by Tony Smith on 22/04/2021.
 *  Copyright © 2025 Tony Smith. All rights reserved.
 */


import Foundation
import AppKit
import QuickLookThumbnailing


class ThumbnailProvider: QLThumbnailProvider {

    // MARK:- Private Properties

    private enum ThumbnailerError: Error {
        case badFileLoad(String)
        case badFileUnreadable(String)
        case badFileUnsupportedEncoding(String)
        case badFileUnsupportedFile(String)
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
                //let data: Data = try Data.init(contentsOf: request.fileURL, options: [.uncached])
                let yamlFileHandle = try FileHandle(forReadingFrom: request.fileURL)
                try yamlFileHandle.seek(toOffset: 0)
                guard let data = try yamlFileHandle.read(upToCount: 1024) else {
                    try yamlFileHandle.close()
                    handler(nil, ThumbnailerError.badFileUnreadable(request.fileURL.path))
                    return
                }

                try yamlFileHandle.close()

                // Get the string's encoding, or fail back to .utf8
                let encoding: String.Encoding = data.stringEncoding ?? .utf8

                // Check the string's encoding generates a valid string
                // NOTE This may not be necessary and so may be removed
                guard let yamlFileString: String = String.init(data: data, encoding: encoding) else {
                    handler(nil, ThumbnailerError.badFileLoad(request.fileURL.path))
                    return
                }

                // Instantiate the common code
                let common = Common(forThumbnail: true)

                // Set the primary drawing frame and a base font size
                let yamlFrame: CGRect = NSMakeRect(CGFloat(BUFFOON_CONSTANTS.THUMBNAIL_SIZE.ORIGIN_X),
                                                   CGFloat(BUFFOON_CONSTANTS.THUMBNAIL_SIZE.ORIGIN_Y),
                                                   CGFloat(BUFFOON_CONSTANTS.THUMBNAIL_SIZE.WIDTH),
                                                   CGFloat(BUFFOON_CONSTANTS.THUMBNAIL_SIZE.HEIGHT))

                // Instantiate an NSTextField to display the NSAttributedString render of the YAML
                let yamlTextField: NSTextField = NSTextField.init(frame: yamlFrame)
                yamlTextField.attributedStringValue = common.getThumbnailString(fromYaml: yamlFileString)

                // FROM 2.0.0
                // From macOS 26.1, make sure thumbnail backgrounds remain white
                // NOTE This may become a setting in future, but for now retain the styling
                //      we have always presented.
                if #available(macOS 26.1, *) {
                    if !common.settings.thumbnailMatchFinderMode {
                        yamlTextField.isBezeled = false
                        yamlTextField.drawsBackground = true
                        yamlTextField.backgroundColor = .white
                    }
                }

                // Generate the bitmap from the rendered YAML text view
                guard let bodyImageRep: NSBitmapImageRep = yamlTextField.bitmapImageRepForCachingDisplay(in: yamlFrame) else {
                    handler(nil, ThumbnailerError.badGfxBitmap)
                    return
                }

                // Draw the YAML view into the bitmap
                yamlTextField.cacheDisplay(in: yamlFrame, to: bodyImageRep)

                if let image: CGImage = bodyImageRep.cgImage {
                    // Calculate image scaling, frame size, etc.
                    let thumbnailFrame: CGRect = NSMakeRect(0.0,
                                                            0.0,
                                                            CGFloat(BUFFOON_CONSTANTS.THUMBNAIL_SIZE.ASPECT) * request.maximumSize.height,
                                                            request.maximumSize.height)
                    let scaleFrame: CGRect = NSMakeRect(10.0,
                                                        20.0,
                                                        thumbnailFrame.width * request.scale - 10.0,
                                                        thumbnailFrame.height * request.scale - 20.0)

                    // Pass a QLThumbnailReply and no error to the supplied handler
                    handler(QLThumbnailReply.init(contextSize: thumbnailFrame.size) { (context) -> Bool in
                        // `scaleFrame` and `cgImage` are immutable
                        context.draw(image, in: scaleFrame, byTiling: false)
                        return true
                    }, nil)
                    
                    return
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
