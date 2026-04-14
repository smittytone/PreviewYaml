/*
 *  AppDelegateFeedback.swift
 *  PreviewYaml
 *  Extension for AppDelegate providing feedback handling functionality.
 *
 *  Created by Tony Smith on 10/04/2026.
 *  Copyright © 2026 Tony Smith. All rights reserved.
 */

import AppKit
import UniformTypeIdentifiers


extension AppDelegate {

    /**
     Set up the UI for the first time.
     */
    internal func initialiseFeedback() {

        // Reset the UI
        self.connectionProgress.stopAnimation(self)
        self.feedbackText.stringValue = ""
        self.messageSizeLabel.stringValue = "0/512"
        self.messageSendButton.isEnabled = false
    }


    /**
     Update UI when we are about to switch to it
     */
    @MainActor
    internal func willShowFeedbackPage() {

        // Disable the Feedback > Send button if we have sent a message.
        // It will be re-enabled by typing something
        self.messageSendButton.isEnabled = (!self.feedbackText.stringValue.isEmpty && !self.hasSentFeedback)
    }


    /**
     Check if feedback has been entered and, if so, whether it has been sent.

     - Returns:
        `true` if there is feedback to warn the user about, otherwise `false`.
     */
    internal func checkFeedbackOnQuit() -> Bool {

        return !(self.feedbackText.stringValue.isEmpty || self.hasSentFeedback)
    }


    /**
     The user clicked the Feedback > Send button, so get the message (if there is one)
     from the text field and send it off.
     */
    @IBAction
    @objc
    private func doSendFeedback(sender: Any) {

        let feedback: String = self.feedbackText.stringValue
        if !feedback.isEmpty  && !self.hasSentFeedback {
            // FROM 2.0.0 -- Use Swift Concurrency
            // NOTE Use of Task and closure required because @IBAction functions
            //      cannot be `async`, but we make an `await` call later on
            Task { @MainActor in
                // Start the connection indicator if it's not already visible,
                // and block tab switching via menus
                self.connectionProgress.startAnimation(self)
                hidePanelGenerators()

                // Post the feedback asynchronously
                let error: FeedbackError = await self.nuSendFeedback(feedback)
                self.connectionProgress.stopAnimation(self)
                if error.code != .noError {
                    // Error - inform the user
                    presentFeedbackError(error)
                } else {
                    // No error - feedback sent successfully
                    presentFeedbackSuccess()
                }
            }
        }
    }


    // MARK: - Alert Functions

    /**
     Present an error message specific to sending feedback.

     This is called from multiple locations: if the initial request can't be created,
     there was a send failure, or a server error.
     */
    internal func presentFeedbackError(_ error: FeedbackError) {

        hidePanelGenerators()
        let alert: NSAlert = makeAlert("Feedback Could Not Be Sent",
                                       "Unfortunately, your comments could not be send at this time. Please try again later.\n\nReason: \(error.localizedDescription)")
        alert.beginSheetModal(for: self.window) { (resp) in
            self.showPanelGenerators()
        }
    }


    /**
     Present a message on successfully sending feedback.

     FROM 2.0.0
     */
    internal func presentFeedbackSuccess() {

        let alert: NSAlert = makeAlert("Thanks For Your Feedback!",
                                       "Your comments have been received and we’ll take a look at them shortly.")
        alert.beginSheetModal(for: self.window) { (resp) in
            self.showPanelGenerators()
            self.hasSentFeedback = true
            self.messageSendButton.isEnabled = false
        }
    }


    // MARK: - Support Functions

    /**
     Build a date string string for feedback usage.

     - Returns: The date string.
     */
    internal func getFeedbackDate() -> String {

        let date: Date = Date()
        let dateFormatter: DateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        return dateFormatter.string(from: date)
    }


    /**
     Build a user-agent string string for feedback usage.

     - Returns: The user-agent string.
     */
    internal func getUserAgent() -> String {

        let sysVer: OperatingSystemVersion = ProcessInfo.processInfo.operatingSystemVersion
        let bundle: Bundle = Bundle.main
        let app: String = bundle.object(forInfoDictionaryKey: "CFBundleExecutable") as! String
        let version: String = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
        let build: String = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as! String
        return "\(app)/\(version)-\(build) (macOS/\(sysVer.majorVersion).\(sysVer.minorVersion).\(sysVer.patchVersion))"
    }


    /**
     Read back the host system's registered UTI for the specified file.

     This is not PII. It used solely for debugging purposes

     - Parameters:
        - filename: The file we'll use to get the UTI.

     - Returns: The file's UTI.
     */
    internal func getLocalFileUTI(_ filename: String) -> String {

        var localUTI: String = "NONE"
        let samplePath = Bundle.main.resourcePath! + "/" + filename

        if FileManager.default.fileExists(atPath: samplePath) {
            // Create a URL reference to the sample file
            let sampleURL = URL(fileURLWithPath: samplePath)

            do {
                // Read back the UTI from the URL
                if let uti: UTType = try sampleURL.resourceValues(forKeys: [.contentTypeKey]).contentType {
                    localUTI = uti.identifier
                }
            } catch {
                // NOP
            }
        }

        return localUTI
    }


    // MARK: - NSTextFieldDelegate Functions

    func controlTextDidChange(_ note: Notification) {

        // Trap text changes so that no more than
        // can be entered into the text field

        if self.feedbackText.stringValue.count > BUFFOON_CONSTANTS.MAX_FEEDBACK_SIZE {
            // FROM 2.0.0
            // Chop the feedback field's attributed string, not its plain string
            let attStr = NSMutableAttributedString(attributedString: self.feedbackText.attributedStringValue)
            attStr.deleteCharacters(in: NSRange(location: BUFFOON_CONSTANTS.MAX_FEEDBACK_SIZE, length: attStr.length - BUFFOON_CONSTANTS.MAX_FEEDBACK_SIZE))
            self.feedbackText.attributedStringValue = attStr as NSAttributedString

            // Tell the user about the limit by flashing the
            // text field red and back
            flashField()
        }

        // Set the button title according to the amount of feedback text
        self.messageSendButton.isEnabled = !self.feedbackText.stringValue.isEmpty
        if self.hasSentFeedback {
            self.hasSentFeedback = false
        }

        // Set the text length label
        self.messageSizeLabel.stringValue = "\(self.feedbackText.stringValue.count)/\(BUFFOON_CONSTANTS.MAX_FEEDBACK_SIZE)"
    }


    /**
     Briefly set the Text Field's background to red.

     FROM 2.0.0
     */
    func flashField() {

        // Make sure we don't have a timer in play
        guard self.timer == nil else { return }

        // Set the background to colour red
        // Must run on `MainActor` and we set `.high` so it's done immediately
        Task(priority: .high) {
            await MainActor.run {
                self.feedbackText.isEnabled = false
                self.feedbackText.backgroundColor = .red
                self.feedbackText.textColor = .white
            }
        }

        // Switch the background back in 0.25 of a second
        self.timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: false, block: { (timer) in
            timer.invalidate()

            // Must run on `MainActor` and we set `.high` so it's done immediately
            Task(priority: .high) {
                await MainActor.run {
                    self.feedbackText.backgroundColor = .textBackgroundColor
                    self.feedbackText.textColor = .labelColor
                    self.feedbackText.isEnabled = true
                    self.timer = nil
                }
            }
        })
    }

}
