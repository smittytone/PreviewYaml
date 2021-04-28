/*
 *  ThumbnailProvider.swift
 *  PreviewYaml
 *
 *  Created by Tony Smith on 22/04/2021.
 *  Copyright © 2021 Tony Smith. All rights reserved.
 */

import QuickLookThumbnailing
import Cocoa
import os.log

class ThumbnailProvider: QLThumbnailProvider {

    // MARK:- Properties
    // NOTE May remove some or all of these later
    public var reportError: NSError? = nil


    // MARK:- QLThumbnailProvider Required Functions

    override func provideThumbnail(for request: QLFileThumbnailRequest, _ handler: @escaping (QLThumbnailReply?, Error?) -> Void) {
        
        // Get the 'show tag' preference
        var doShowTag: Bool = true
        if let defaults = UserDefaults(suiteName: MNU_SECRETS.PID + ".suite.preview-yaml") {
            defaults.synchronize()
            doShowTag = defaults.bool(forKey: "com-bps-previewyaml-do-show-tag")
        }

        // Determine the thumbnail frame for the 'QLThumbnailReply()' call
        // NOTE This is always square, with height matched to width, so adjust
        //      to a 3:4 aspect ratio to maintain the macOS standard doc icon width
        let thumbnailFrame: CGRect = NSMakeRect(0.0,
                                                0.0,
                                                CGFloat(BUFFOON_CONSTANTS.THUMBNAIL_SIZE.ASPECT) * request.maximumSize.height,
                                                request.maximumSize.height)

        handler(QLThumbnailReply.init(contextSize: thumbnailFrame.size) { () -> Bool in

            let success = autoreleasepool { () -> Bool in
                // Load the source file using a co-ordinator as we don't know what thread this function
                // will be executed in when it's called by macOS' QuickLook code
                if FileManager.default.isReadableFile(atPath: request.fileURL.path) {
                    // Only proceed if the file is accessible from here
                    do {
                        // Get the file contents as a string
                        let data: Data = try Data.init(contentsOf: request.fileURL, options: [.uncached])
                        if let yamlFileString: String = String.init(data: data, encoding: .utf8) {
                            // Get the Attributed String
                            let yamlAttString: NSAttributedString = getAttributedString(yamlFileString, true)

                            // Set the primary drawing frame and a base font size
                            let yamlFrame: CGRect = CGRect.init(x: BUFFOON_CONSTANTS.THUMBNAIL_SIZE.ORIGIN_X,
                                                                y: BUFFOON_CONSTANTS.THUMBNAIL_SIZE.ORIGIN_Y,
                                                                width: BUFFOON_CONSTANTS.THUMBNAIL_SIZE.WIDTH,
                                                                height: BUFFOON_CONSTANTS.THUMBNAIL_SIZE.HEIGHT)

                            // Instantiate an NSTextView to display the NSAttributedString render of the markdown
                            let yamlTextView: NSTextView = NSTextView.init(frame: yamlFrame)
                            yamlTextView.backgroundColor = NSColor.white

                            // Write the markdown rendered as an NSAttributedString into the view's text storage
                            if let yamlTextStorage: NSTextStorage = yamlTextView.textStorage {
                                yamlTextStorage.setAttributedString(yamlAttString)
                            } else {
                                return false
                            }

                            // Also generate text for the bottom-of-thumbnail file type tag,
                            // if the user has this set as a preference
                            var tagTextView: NSTextView? = nil
                            var tagFrame: CGRect? = nil

                            if doShowTag {
                                // Define the frame of the tag area
                                tagFrame = CGRect.init(x: BUFFOON_CONSTANTS.THUMBNAIL_SIZE.ORIGIN_X,
                                                       y: BUFFOON_CONSTANTS.THUMBNAIL_SIZE.ORIGIN_Y,
                                                       width: BUFFOON_CONSTANTS.THUMBNAIL_SIZE.WIDTH,
                                                       height: BUFFOON_CONSTANTS.THUMBNAIL_SIZE.TAG_HEIGHT)

                                // Instantiate an NSTextView to display the NSAttributedString render of the tag,
                                // this time with a clear background
                                // NOTE 'tagTextView' is an optional
                                tagTextView = NSTextView.init(frame: tagFrame!)
                                tagTextView!.backgroundColor = NSColor.clear

                                // Write the tag rendered as an NSAttributedString into the view's text storage
                                if let tagTextStorage: NSTextStorage = tagTextView!.textStorage {
                                    // NOTE We use 'request.maximumSize' for more accurate results
                                    tagTextStorage.setAttributedString(self.getTagString("YAML", request.maximumSize.width))
                                } else {
                                    return false
                                }
                            }

                            // Generate the bitmap from the rendered markdown text view
                            let imageRep: NSBitmapImageRep? = yamlTextView.bitmapImageRepForCachingDisplay(in: yamlFrame)
                            if imageRep != nil {
                                // Draw into the bitmap first the markdown view...
                                yamlTextView.cacheDisplay(in: yamlFrame, to: imageRep!)

                                // ...then the tag view
                                if tagTextView != nil && tagFrame != nil {
                                    tagTextView!.cacheDisplay(in: tagFrame!, to: imageRep!)
                                }

                                let success = imageRep!.draw(in: thumbnailFrame)
                                return success
                            }
                        }
                    } catch {
                        // NOP -- just fall through
                    }
                }

                // We didn't draw anything because of an error
                // NOTE Technically we should call 'handler(nil, error)'
                return false
            }

            // Return the outcome of the drawing code relayed
            // via the autorelease pool
            return success
        }, nil)
    }


    func getTagString(_ tag: String, _ width: CGFloat) -> NSAttributedString {

        // Set the text for the bottom-of-thumbnail file type tag

        // Set the paragraph style we'll use -- just centred text
        let style: NSMutableParagraphStyle = NSMutableParagraphStyle.init()
        style.alignment = .center

        // Build the tag's string attributes
        let tagAtts: [NSAttributedString.Key: Any] = [
            .paragraphStyle: style,
            .font: NSFont.systemFont(ofSize: 120.0),
            .foregroundColor: (width < 128.0 ? NSColor.black : NSColor.gray)
        ]

        // Return the attributed string built from the tag
        return NSAttributedString.init(string: tag, attributes: tagAtts)
    }

}
