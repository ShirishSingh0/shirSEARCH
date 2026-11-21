import Cocoa
import Foundation
import CoreGraphics

// ============================================================================
// shirSEARCH for macOS ⚡
// Pure Stealth Whole-Screen AI Question Solver & Menu Bar HUD
// ============================================================================

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var currentApiKey: String = ""
    var isProcessing: Bool = false
    var pollerThread: Thread?
    var isPollerRunning: Bool = true
    var lastTriggerTime: TimeInterval = 0

    let defaultModel = "gemini-2.5-flash-lite"
    let launchAgentIdentifier = "com.shirish.shirsearch"

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Run as stealth accessory app (no Dock icon, Menu Bar only)
        NSApp.setActivationPolicy(.accessory)

        loadApiKey()
        setupStatusBar()
        checkScreenRecordingPermission(promptIfNeeded: false)
        startKeyPoller()
        logToFile("shirSEARCH macOS started in Stealth Menu Bar Mode. Ready for triggers.")
    }

    func applicationWillTerminate(_ notification: Notification) {
        isPollerRunning = false
        pollerThread?.cancel()
    }

    // MARK: - Menu Bar Setup
    func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.title = "★ shirSEARCH"
            button.toolTip = "shirSEARCH (Ready: Cmd+Ctrl+Opt or F9)"
        }

        rebuildMenu()
    }

    func rebuildMenu() {
        let menu = NSMenu()

        let scanItem = NSMenuItem(title: "⚡ Scan Whole Screen (Cmd+Ctrl+Opt / F9)", action: #selector(menuTriggerScan), keyEquivalent: "")
        scanItem.target = self
        menu.addItem(scanItem)

        menu.addItem(NSMenuItem.separator())

        let keyItem = NSMenuItem(title: "🔑 Set Gemini API Key...", action: #selector(showApiKeyDialog), keyEquivalent: "")
        keyItem.target = self
        menu.addItem(keyItem)

        let permItem = NSMenuItem(title: "🛡️ Fix Screen Recording Permission...", action: #selector(showScreenRecordingPermissionAlert), keyEquivalent: "")
        permItem.target = self
        menu.addItem(permItem)

        let loginItem = NSMenuItem(title: "Start at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        loginItem.target = self
        loginItem.state = isLaunchAtLoginEnabled() ? .on : .off
        menu.addItem(loginItem)

        let resetItem = NSMenuItem(title: "🔄 Reset Status", action: #selector(resetStatus), keyEquivalent: "")
        resetItem.target = self
        menu.addItem(resetItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit shirSEARCH", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    func updateStatus(_ title: String, toolTip: String = "") {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let button = self.statusItem.button else { return }
            button.title = title
            if !toolTip.isEmpty {
                button.toolTip = toolTip
            }
        }
    }

    @objc func resetStatus() {
        updateStatus("★ shirSEARCH", toolTip: "shirSEARCH (Ready: Cmd+Ctrl+Opt or F9)")
    }

    @objc func menuTriggerScan() {
        triggerScanAndSolve()
    }

    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    // MARK: - API Key Management
    func getAppDirectory() -> URL {
        return Bundle.main.bundleURL.deletingLastPathComponent()
    }

    func getLocalKeyFileURL() -> URL {
        return getAppDirectory().appendingPathComponent("apikey.txt")
    }

    func getUserKeyFileURL() -> URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".shirsearch/apikey.txt")
    }

    func loadApiKey() {
        // 1. Check current directory apikey.txt
        let localURL = getLocalKeyFileURL()
        if let key = try? String(contentsOf: localURL, encoding: .utf8) {
            let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                currentApiKey = trimmed
                logToFile("Loaded API key from local apikey.txt")
                return
            }
        }

        // 2. Check ~/.shirsearch/apikey.txt
        let userURL = getUserKeyFileURL()
        if let key = try? String(contentsOf: userURL, encoding: .utf8) {
            let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                currentApiKey = trimmed
                logToFile("Loaded API key from ~/.shirsearch/apikey.txt")
                return
            }
        }

        currentApiKey = ""
    }

    func saveApiKey(_ key: String) {
        currentApiKey = key

        // Save to ~/.shirsearch/apikey.txt
        let userFolder = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".shirsearch")
        try? FileManager.default.createDirectory(at: userFolder, withIntermediateDirectories: true, attributes: nil)
        let userURL = userFolder.appendingPathComponent("apikey.txt")
        try? key.write(to: userURL, atomically: true, encoding: .utf8)

        // Also save to current directory if writable
        let localURL = getLocalKeyFileURL()
        try? key.write(to: localURL, atomically: true, encoding: .utf8)

        logToFile("Saved API key successfully.")
    }

    @objc func showApiKeyDialog() {
        let alert = NSAlert()
        alert.messageText = "shirSEARCH - Set Gemini API Key"
        alert.informativeText = "Enter your Google Gemini API Key (starts with AIzaSy...):"
        alert.addButton(withTitle: "Save Key")
        alert.addButton(withTitle: "Cancel")

        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 360, height: 26))
        input.stringValue = currentApiKey
        input.placeholderString = "AIzaSy..."
        alert.accessoryView = input

        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            let newKey = input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !newKey.isEmpty {
                saveApiKey(newKey)
                updateStatus("★ [Key Saved]", toolTip: "API Key saved successfully!")
            }
        }
    }

    // MARK: - Launch at Login (macOS LaunchAgent)
    func launchAgentURL() -> URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent("Library/LaunchAgents/\(launchAgentIdentifier).plist")
    }

    func isLaunchAtLoginEnabled() -> Bool {
        return FileManager.default.fileExists(atPath: launchAgentURL().path)
    }

    @objc func toggleLaunchAtLogin() {
        let enabled = isLaunchAtLoginEnabled()
        let plistURL = launchAgentURL()

        if enabled {
            try? FileManager.default.removeItem(at: plistURL)
            logToFile("Launch at login disabled.")
        } else {
            let execPath = Bundle.main.executablePath ?? CommandLine.arguments[0]
            let plistContent = """
            <?xml version="1.0" encoding="UTF-8"?>
            <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
            <plist version="1.0">
            <dict>
                <key>Label</key>
                <string>\(launchAgentIdentifier)</string>
                <key>ProgramArguments</key>
                <array>
                    <string>\(execPath)</string>
                </array>
                <key>RunAtLoad</key>
                <true/>
                <key>KeepAlive</key>
                <false/>
            </dict>
            </plist>
            """

            let dir = plistURL.deletingLastPathComponent()
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
            try? plistContent.write(to: plistURL, atomically: true, encoding: .utf8)
            logToFile("Launch at login enabled: \(execPath)")
        }

        rebuildMenu()
    }

    // MARK: - Global Key Poller
    func startKeyPoller() {
        pollerThread = Thread { [weak self] in
            while let self = self, self.isPollerRunning {
                // Keycodes on macOS:
                // Command: 0x37 (L), 0x36 (R)
                // Control: 0x3B (L), 0x3E (R)
                // Option:  0x3A (L), 0x3D (R)
                // S Key:   0x01
                // F9 Key:  0x65

                let cmd = CGEventSource.keyState(.combinedSessionState, key: 0x37) ||
                          CGEventSource.keyState(.combinedSessionState, key: 0x36)

                let ctrl = CGEventSource.keyState(.combinedSessionState, key: 0x3B) ||
                           CGEventSource.keyState(.combinedSessionState, key: 0x3E)

                let opt = CGEventSource.keyState(.combinedSessionState, key: 0x3A) ||
                          CGEventSource.keyState(.combinedSessionState, key: 0x3D)

                let sKey = CGEventSource.keyState(.combinedSessionState, key: 0x01)
                let f9Key = CGEventSource.keyState(.combinedSessionState, key: 0x65)

                let triggerCombo1 = cmd && ctrl && opt
                let triggerCombo2 = cmd && opt && sKey
                let triggerCombo3 = f9Key

                if triggerCombo1 || triggerCombo2 || triggerCombo3 {
                    let now = Date().timeIntervalSince1970
                    if now - self.lastTriggerTime > 1.5 && !self.isProcessing {
                        self.lastTriggerTime = now
                        let trigName = triggerCombo1 ? "Cmd+Ctrl+Opt" : (triggerCombo2 ? "Cmd+Opt+S" : "F9")
                        self.logToFile("Triggered via \(trigName)")

                        DispatchQueue.main.async {
                            self.triggerScanAndSolve()
                        }
                    }
                }

                usleep(25000) // 40Hz
            }
        }

        pollerThread?.qualityOfService = .userInteractive
        pollerThread?.start()
    }

    // MARK: - Screen Capture & Solve
    func triggerScanAndSolve() {
        guard !isProcessing else { return }

        if currentApiKey.isEmpty {
            updateStatus("⚠️ [Set API Key]", toolTip: "Click menu to set your Gemini API key")
            showApiKeyDialog()
            return
        }

        isProcessing = true
        updateStatus("⚡ Scanning...", toolTip: "Capturing screen and analyzing with Gemini...")

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            guard let base64Data = self.captureScreenAsBase64() else {
                self.logToFile("Failed to capture screen. Screen Recording permission is likely missing.")
                self.updateStatus("❌ [Capture Error]", toolTip: "Screen capture failed. Check Screen Recording permissions.")
                self.isProcessing = false
                DispatchQueue.main.async {
                    self.showScreenRecordingPermissionAlert()
                }
                return
            }

            self.callGeminiVision(base64Image: base64Data) { result in
                DispatchQueue.main.async {
                    self.isProcessing = false
                    switch result {
                    case .success(let responseText):
                        self.handleGeminiSuccess(responseText)
                    case .failure(let error):
                        self.logToFile("Gemini error: \(error.localizedDescription)")
                        self.updateStatus("❌ [Solve Error]", toolTip: error.localizedDescription)
                    }
                }
            }
        }
    }

    // MARK: - Screen Recording Permission Helpers
    func checkScreenRecordingPermission(promptIfNeeded: Bool = false) {
        if #available(macOS 10.15, *) {
            let hasAccess = CGPreflightScreenCaptureAccess()
            if !hasAccess {
                logToFile("Screen recording access not granted yet.")
                if promptIfNeeded {
                    showScreenRecordingPermissionAlert()
                }
            } else {
                logToFile("Screen recording access verified.")
            }
        }
    }

    @objc func showScreenRecordingPermissionAlert() {
        if #available(macOS 10.15, *) {
            CGRequestScreenCaptureAccess()
        }

        let alert = NSAlert()
        alert.messageText = "Screen Recording Permission Required"
        alert.informativeText = "macOS requires Screen Recording permission for shirSEARCH to capture and solve questions.\n\n1. Click 'Open System Settings' below\n2. Turn ON the toggle for Terminal (or shirSEARCH.app)\n3. If it is already on, toggle it OFF and ON again\n4. Try pressing Cmd+Ctrl+Opt or F9 again!"
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")

        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    func captureScreenAsBase64() -> String? {
        // Strategy 1: CoreGraphics direct in-memory capture of main display
        let displayID = CGMainDisplayID()
        if let cgImage = CGDisplayCreateImage(displayID) {
            let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
            if let jpegData = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.85]),
               jpegData.count > 1000 {
                return jpegData.base64EncodedString()
            }
        }

        // Strategy 2: Native screencapture CLI fallback
        let tempFile = NSTemporaryDirectory() + "shirsearch_capture.jpg"
        try? FileManager.default.removeItem(atPath: tempFile)

        let process = Process()
        process.launchPath = "/usr/sbin/screencapture"
        process.arguments = ["-x", "-t", "jpg", tempFile]
        process.launch()
        process.waitUntilExit()

        if FileManager.default.fileExists(atPath: tempFile),
           let fileData = try? Data(contentsOf: URL(fileURLWithPath: tempFile)),
           fileData.count > 1000 {
            try? FileManager.default.removeItem(atPath: tempFile)
            return fileData.base64EncodedString()
        }

        return nil
    }

    func callGeminiVision(base64Image: String, completion: @escaping (Result<String, Error>) -> Void) {
        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/\(defaultModel):generateContent?key=\(currentApiKey)"
        guard let url = URL(string: urlString) else {
            completion(.failure(NSError(domain: "shirSEARCH", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid API URL"])))
            return
        }

        let promptText = "Analyze this screen capture immediately. Find the main multiple-choice or true/false question. Answer with ONLY a single line in this exact format: [ANSWER: X] Reasoning. Where X is A, B, C, or D (or True/False). Keep explanation strictly under 15 words. Be accurate and fast."

        let jsonPayload: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": promptText],
                        [
                            "inline_data": [
                                "mime_type": "image/jpeg",
                                "data": base64Image
                            ]
                        ]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.1,
                "maxOutputTokens": 60
            ]
        ]

        guard let requestData = try? JSONSerialization.data(withJSONObject: jsonPayload, options: []) else {
            completion(.failure(NSError(domain: "shirSEARCH", code: 400, userInfo: [NSLocalizedDescriptionKey: "Failed to encode JSON payload"])))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = requestData
        request.timeoutInterval = 15

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(NSError(domain: "shirSEARCH", code: 500, userInfo: [NSLocalizedDescriptionKey: "Empty response from Gemini"])))
                return
            }

            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                let errBody = String(data: data, encoding: .utf8) ?? "Unknown HTTP \(httpResponse.statusCode)"
                completion(.failure(NSError(domain: "shirSEARCH", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "API Error (\(httpResponse.statusCode)): \(errBody)"])))
                return
            }

            guard let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                  let candidates = json["candidates"] as? [[String: Any]],
                  let firstCandidate = candidates.first,
                  let content = firstCandidate["content"] as? [String: Any],
                  let parts = content["parts"] as? [[String: Any]],
                  let firstPart = parts.first,
                  let text = firstPart["text"] as? String else {
                completion(.failure(NSError(domain: "shirSEARCH", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to parse Gemini response"])))
                return
            }

            completion(.success(text.trimmingCharacters(in: .whitespacesAndNewlines)))
        }

        task.resume()
    }

    func handleGeminiSuccess(_ responseText: String) {
        logToFile("Gemini Answer: \(responseText)")

        // Extract option letter A, B, C, D (or True/False)
        var solvedLetter = "?"
        var explanation = responseText

        let pattern = #"\[ANSWER:\s*([A-Za-z0-9]+)\]"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: responseText, options: [], range: NSRange(location: 0, length: responseText.utf16.count)) {
            if let letterRange = Range(match.range(at: 1), in: responseText) {
                solvedLetter = String(responseText[letterRange]).uppercased()
            }
            explanation = regex.stringByReplacingMatches(in: responseText, options: [], range: NSRange(location: 0, length: responseText.utf16.count), withTemplate: "").trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Color emoji badges for quick glance in Menu Bar
        let badge: String
        switch solvedLetter {
        case "A": badge = "🟢 A"
        case "B": badge = "🔵 B"
        case "C": badge = "🟣 C"
        case "D": badge = "🟠 D"
        default:  badge = "★ [\(solvedLetter)]"
        }

        let summary = explanation.replacingOccurrences(of: "\n", with: " ")
        let menuTitle = "\(badge)  \(summary.prefix(30))"
        let tooltipText = "Option: \(solvedLetter)\n\(responseText)"

        updateStatus(menuTitle, toolTip: tooltipText)
    }

    // MARK: - Logging
    func logToFile(_ msg: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let timestamp = formatter.string(from: Date())
        let line = "[\(timestamp)] \(msg)\n"

        let logURL = getAppDirectory().appendingPathComponent("shirSEARCH.log")
        if let handle = try? FileHandle(forWritingTo: logURL) {
            handle.seekToEndOfFile()
            if let data = line.data(using: .utf8) {
                handle.write(data)
            }
            try? handle.close()
        } else {
            try? line.write(to: logURL, atomically: true, encoding: .utf8)
        }
    }
}

// MARK: - Main Application Launch
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
