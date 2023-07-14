//
//  AppDelegate.swift
//  RenderDemo
//
//  Created by Tony Smith on 10/07/2023.
//

import Cocoa

@main
class AppDelegate:  NSObject,
                    NSApplicationDelegate,
                    NSOpenSavePanelDelegate {


    @IBOutlet var window: NSWindow!
    @IBOutlet var mainView: NSView!
    @IBOutlet var filePathLabel: NSTextField!
    @IBOutlet var previewTextView: NSTextView!
    @IBOutlet var previewScrollView: NSScrollView!


    private var openDialog: NSOpenPanel? = nil
    private var isOpenDialogVisible: Bool = false
    private var common: Common = Common.init(false)

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }


    @IBAction private func doLoadYamlFile(_ sender: Any) {

        self.openDialog = NSOpenPanel.init()

        self.openDialog!.canChooseFiles = true
        self.openDialog!.canChooseDirectories = false
        self.openDialog!.allowsMultipleSelection = false

        self.openDialog!.delegate = self
        self.openDialog!.directoryURL = URL.init(fileURLWithPath: "")

        if self.openDialog!.runModal() == .OK {
            var reportError: NSError? = nil

            do {
                if let yamlUrl: URL = self.openDialog!.url {
                    self.filePathLabel.stringValue = yamlUrl.absoluteString

                    // Get the file contents as a string
                    let data: Data = try Data.init(contentsOf: yamlUrl, options: [.uncached])

                    // Get the string's encoding, or fail back to .utf8
                    let encoding: String.Encoding = data.stringEncoding ?? .utf8

                    if let yamlFileString: String = String.init(data: data, encoding: encoding) {
                        // Get the key string first
                        let yamlAttString: NSAttributedString = common.getAttributedString(yamlFileString)

                        self.previewTextView.backgroundColor = common.doShowLightBackground ? NSColor.init(white: 1.0, alpha: 0.9) : NSColor.textBackgroundColor
                        self.previewScrollView.scrollerKnobStyle = common.doShowLightBackground ? .dark : .light

                        if let renderTextStorage: NSTextStorage = self.previewTextView.textStorage {
                            renderTextStorage.beginEditing()
                            renderTextStorage.setAttributedString(yamlAttString)
                            renderTextStorage.endEditing()

                            // Add the subview to the instance's own view and draw
                            //self.mainView.display()
                            return
                        }

                        // We can't access the preview NSTextView's NSTextStorage
                        reportError = setError(BUFFOON_CONSTANTS.ERRORS.CODES.BAD_TS_STRING)
                    } else {
                        // FROM 1.1.2
                        // We couldn't convert to data to a valid encoding
                        let errDesc: String = "\(BUFFOON_CONSTANTS.ERRORS.MESSAGES.BAD_TS_STRING) \(encoding)"
                        reportError = NSError(domain: BUFFOON_CONSTANTS.APP_CODE_PREVIEWER,
                                              code: BUFFOON_CONSTANTS.ERRORS.CODES.BAD_MD_STRING,
                                              userInfo: [NSLocalizedDescriptionKey: errDesc])
                    }
                }
            } catch {
                // We couldn't read the file so set an appropriate error to report back
                reportError = setError(BUFFOON_CONSTANTS.ERRORS.CODES.FILE_WONT_OPEN)
            }
        }

        self.openDialog = nil
    }


    /**
     Generate an NSError for an internal error, specified by its code.

     Codes are listed in `Constants.swift`

     - Parameters:
        - code: The internal error code.

     - Returns: The described error as an NSError.
     */
    func setError(_ code: Int) -> NSError {

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
}

