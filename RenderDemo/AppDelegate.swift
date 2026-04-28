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

    // MARK: - Class UI Properies
    
    @IBOutlet weak var window: NSWindow!
    @IBOutlet weak var mainView: NSView!
    @IBOutlet weak var previewTextView: NSTextView!
    @IBOutlet weak var previewScrollView: NSScrollView!
    @IBOutlet weak var modeButton: NSButton!
    @IBOutlet weak var indentButton: NSButton!
    @IBOutlet weak var reloadButton: NSButton!
    @IBOutlet weak var reloadMenuItem: NSMenuItem!
    @IBOutlet weak var progress: NSProgressIndicator!
    @IBOutlet weak var thumbButton: NSButton!


    // MARK: - Private Properies

    private var openDialog: NSOpenPanel? = nil
    private var _currentURL: URL? = nil
    private var currentDirURL: URL? = nil
    private var renderAsDark: Bool = true
    private var renderIndents: Bool = false
    private var common: Common? = nil

    private var currentURL: URL? {
        get {
            return self._currentURL
        }
        set(new) {
            self._currentURL = new
            self.reloadButton.isEnabled = new != nil
            self.reloadMenuItem.isEnabled = new != nil
        }
    }

    
    // MARK: - Class Lifecycle Functions
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        
        // Set the mode button
        self.modeButton.state = self.renderAsDark ? .on : .off
        self.indentButton.state = self.renderIndents ? .on : .off
        self.reloadButton.isEnabled = false
        self.reloadMenuItem.isEnabled = false
        self.progress.isHidden = true

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.doRender),
                                               name: NSNotification.Name(rawValue: "com.bps.rd.load"),
                                               object: nil)

        // Centre the main window and display
        self.window.center()
        self.window.makeKeyAndOrderFront(self)
    }
    
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {

        // When the main window closed, shut down the app
        return true
    }


    // MARK: - Action Functions
    
    @IBAction
    private func doLoadFile(_ sender: Any) {

        let openPanel = NSOpenPanel()
        openPanel.delegate = self
        openPanel.canChooseFiles = true
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        if self.currentDirURL != nil {
            openPanel.directoryURL = self.currentDirURL!
        } else {
            openPanel.directoryURL = FileManager.default.homeDirectoryForCurrentUser
        }

        openPanel.beginSheetModal(for: self.window) { (response) in
            if response == .OK {
                self.currentURL = openPanel.url
                self.currentDirURL = openPanel.directoryURL
                NotificationCenter.default.post(Notification(name: Notification.Name(rawValue: "com.bps.rd.load")))
            }
        }
    }


    @IBAction
    private func doReloadFile(_ sender: Any) {

        doRender(Notification(name: Notification.Name(rawValue: "")))
    }

    @IBAction
    private func doSwitchMode(_ sender: Any) {

        self.renderAsDark = self.modeButton.state == .on
        doReRenderFile(self)
    }


    @IBAction
    private func doReRenderFile(_ sender: Any) {

        wenderFile()
    }


    @objc
    func wenderFile() {

        Task { @MainActor in
            self.progress.isHidden = false
            self.progress.startAnimation(self)

            let possibleError: NSError? = await renderContent(self.currentURL)
            self.progress.stopAnimation(self)

            if possibleError != nil {
                // Pop up an alert
                let errorAlert: NSAlert = NSAlert(error: possibleError!)
                await errorAlert.beginSheetModal(for: self.window)
            }
        }
   }


    @IBAction
    private func doSetIndentCharacter(_ sender: Any) {

        self.renderIndents = self.indentButton.state == .on
        doReRenderFile(self)
    }

    
    // MARK: - Rendering Functions

    @objc
    private func doRender(_ note: Notification) {

        self.progress.isHidden = false
        self.progress.startAnimation(self)
        let _ = Timer.scheduledTimer(timeInterval: 0.5, target: self, selector: #selector(self.wenderFile), userInfo: nil, repeats: false)

    }

    @MainActor
    private func renderContent(_ fileToRender: URL?) async -> NSError? {


        var reportError: NSError? = nil

        self.common = Common(forThumbnail: false)

        do {
            if let yamlUrl: URL = fileToRender {
                self.window.title = yamlUrl.absoluteString

                // Get the file contents as a string
                let data: Data = try Data(contentsOf: yamlUrl, options: [.uncached])

                // Get the string's encoding, or fail back to .utf8
                let encoding: String.Encoding = data.stringEncoding ?? .utf8

                if let yamlString: String = String(data: data, encoding: encoding) {

                    self.common!.doShowLightBackground = !self.renderAsDark
                    self.common!.resetStylesOnModeChange()

                    /* OLD 1.x ENGINE STUFF
                    let regexTrue = try! NSRegularExpression(pattern: ":[\\s]*true")
                    let jsonStringTrue: String = regexTrue.stringByReplacingMatches(in: jsonString,
                                                                                    options: [],
                                                                                    range: NSMakeRange(0, jsonString.count),
                                                                                    withTemplate: ": \"JSON-TRUE\"")

                    let regexFalse = try! NSRegularExpression(pattern: ":[\\s]*false")
                    let jsonStringFalse: String = regexFalse.stringByReplacingMatches(in: jsonStringTrue,
                                                                                      options: [],
                                                                                      range: NSMakeRange(0, jsonStringTrue.count),
                                                                                      withTemplate: ": \"JSON-FALSE\"")

                    // Get the key string first
                    let jsonDataCoded: Data = jsonStringFalse.data(using: encoding) ?? data
                    let jsonAttString: NSAttributedString = common.getAttributedString(jsonDataCoded)
                     */

                    let attString: NSAttributedString
                    if self.thumbButton.state == .on {
                        attString = self.common!.getThumbnailString(fromYaml: yamlString)
                    } else {
                        attString = await self.common!.getPreviewString(fromYaml: yamlString)
                    }
                    
                    self.previewTextView.backgroundColor = self.common!.doShowLightBackground ? NSColor(white: 1.0, alpha: 0.9) : NSColor.textBackgroundColor
                    self.previewScrollView.scrollerKnobStyle = self.common!.doShowLightBackground ? .dark : .light

                    // Rescale the text view
                    if common!.tableWidth > self.previewTextView.frame.width {
                        self.previewTextView.setFrameSize(NSSize(width: self.common!.tableWidth + 20.0, height: self.previewTextView.frame.size.height))
                    }

                    // Render the attributed string
                    if let renderTextStorage: NSTextStorage = self.previewTextView.textStorage {
                        renderTextStorage.beginEditing()
                        renderTextStorage.setAttributedString(attString)
                        renderTextStorage.endEditing()

#if DEBUG
                        print("********** END ************")
#endif
                        
                        self.common = nil
                        return nil
                    }

                    // We can't access the preview NSTextView's NSTextStorage
                    reportError = setError(BUFFOON_CONSTANTS.ERRORS.CODES.BAD_TS_STRING)
                } else {
                    // We couldn't convert to data to a valid encoding
                    let errDesc: String = "\(BUFFOON_CONSTANTS.ERRORS.MESSAGES.BAD_TS_STRING) \(encoding)"
                    reportError = NSError(domain: BUFFOON_CONSTANTS.APP_CODE_PREVIEWER,
                                          code: BUFFOON_CONSTANTS.ERRORS.CODES.BAD_MD_STRING,
                                          userInfo: [NSLocalizedDescriptionKey: errDesc])
                }
            } else {
                // No file selected
                let errDesc: String = "No file selected to render"
                reportError = NSError(domain: BUFFOON_CONSTANTS.APP_CODE_PREVIEWER,
                                      code: BUFFOON_CONSTANTS.ERRORS.CODES.BAD_MD_STRING,
                                      userInfo: [NSLocalizedDescriptionKey: errDesc])
            }
        } catch {
            // We couldn't read the file so set an appropriate error to report back
            reportError = setError(BUFFOON_CONSTANTS.ERRORS.CODES.FILE_WONT_OPEN)
        }

        self.common = nil
        return reportError
        
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
