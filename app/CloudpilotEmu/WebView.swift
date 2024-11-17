import AuthenticationServices
import SafariServices
import UIKit
@preconcurrency import WebKit

private var downloadDir: URL?
private var downloads: [WKDownload: URL] = [:]

func createWebView(container: UIView, WKND: WKNavigationDelegate, NSO: NSObject)
    -> (webView: WKWebView, javascriptApiController: JavaScriptApiController)
{
    let config = WKWebViewConfiguration()

    config.limitsNavigationsToAppBoundDomains = true
    config.allowsInlineMediaPlayback = true
    config.preferences.javaScriptCanOpenWindowsAutomatically = true
    config.preferences.setValue(true, forKey: "standalone")
    config.mediaTypesRequiringUserActionForPlayback = []

    if #available(iOS 15.4, *) {
        config.preferences.isSiteSpecificQuirksModeEnabled = false
    }

    if #available(iOS 17.0, *) {
        config.preferences.inactiveSchedulingPolicy = .suspend
    }

    config.userContentController = WKUserContentController()
    let javascriptApiController = JavaScriptApiController()

    config.userContentController.addScriptMessageHandler(
        javascriptApiController, contentWorld: WKContentWorld.page,
        name: "nativeCall")

    let webView = WKWebView(
        frame: calcWebviewFrame(webviewView: container), configuration: config)

    javascriptApiController.webView = webView

    webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    webView.navigationDelegate = WKND
    webView.scrollView.bounces = false
    webView.scrollView.contentInsetAdjustmentBehavior = .never
    webView.allowsBackForwardNavigationGestures = false

    let deviceModel = UIDevice.current.model
    let osVersion = UIDevice.current.systemVersion
    webView.configuration.applicationNameForUserAgent = "Safari/604.1"
    webView.customUserAgent =
        "Mozilla/5.0 (\(deviceModel); CPU \(deviceModel) OS \(osVersion.replacingOccurrences(of: ".", with: "_")) like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/\(osVersion) Mobile/15E148 Safari/604.1 PWAShell cpe-native-api-1"

    webView.addObserver(
        NSO, forKeyPath: #keyPath(WKWebView.estimatedProgress),
        options: NSKeyValueObservingOptions.new, context: nil)

    if #available(iOS 16.4, *) {
        webView.isInspectable = true
    }

    downloadDir = setupDownloadsDirectory()
    print("temporary download area is \(getDownloadDir().path)")

    return (webView, javascriptApiController)
}

func getDownloadDir() -> URL {
    return downloadDir ?? FileManager.default.temporaryDirectory
}

func setupDownloadsDirectory() -> URL? {
    let fileManager = FileManager.default
    let downloadDirectory = fileManager.temporaryDirectory
        .appendingPathComponent("cpe-downloads")

    var exists = fileManager.fileExists(atPath: downloadDirectory.path)

    if exists {
        do {
            try fileManager.removeItem(at: downloadDirectory)
        } catch {
            print(
                "\(downloadDirectory.path) exists and cannot be removed: \(error)"
            )
            return nil
        }

        exists = false
    }

    if !exists {
        do {
            try fileManager.createDirectory(
                at: downloadDirectory, withIntermediateDirectories: true)
        } catch {
            print(
                "failed to create downloads directory at \(downloadDirectory.path): \(error)"
            )
            return nil
        }
    }

    return downloadDirectory
}

func calcWebviewFrame(webviewView: UIView) -> CGRect {
    let winScene = UIApplication.shared.connectedScenes.first
    let windowScene = winScene as! UIWindowScene
    let statusBarHeight =
        windowScene.statusBarManager?.statusBarFrame.height ?? 0

    switch displayMode {
    case "fullscreen":
        return CGRect(
            x: 0, y: 0, width: webviewView.frame.width,
            height: webviewView.frame.height)

    default:
        let windowHeight = webviewView.frame.height - statusBarHeight
        return CGRect(
            x: 0, y: statusBarHeight, width: webviewView.frame.width,
            height: windowHeight)
    }
}

extension ViewController: WKUIDelegate, WKDownloadDelegate {
    // redirect new tabs to main webview
    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        if navigationAction.targetFrame == nil {
            webView.load(navigationAction.request)
        }
        return nil
    }
    // restrict navigation to target host, open external links in 3rd party apps
    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        if navigationAction.request.url?.scheme == "about" {
            return decisionHandler(.allow)
        }
        if navigationAction.shouldPerformDownload
            || navigationAction.request.url?.scheme == "blob"
        {
            return decisionHandler(.download)
        }

        if let requestUrl = navigationAction.request.url {
            if requestUrl.host != nil {
                if requestUrl.absoluteString.starts(
                    with: rootUrlStable.absoluteString)
                    || requestUrl.absoluteString.starts(
                        with: rootUrlPreview.absoluteString)
                {
                    // Open in main webview
                    decisionHandler(.allow)
                    return
                }

                if navigationAction.navigationType == .other
                    && navigationAction.value(forKey: "syntheticClickType")
                        as! Int == 0
                    && (navigationAction.targetFrame != nil)
                    // no error here, fake warning
                    && (navigationAction.sourceFrame != nil)
                {
                    decisionHandler(.allow)
                    return
                } else {
                    decisionHandler(.cancel)
                }

                if ["http", "https"].contains(
                    requestUrl.scheme?.lowercased() ?? "")
                {
                    // Can open with SFSafariViewController
                    let safariViewController = SFSafariViewController(
                        url: requestUrl)
                    self.present(
                        safariViewController, animated: true, completion: nil)
                } else {
                    // Scheme is not supported or no scheme is given, use openURL
                    if UIApplication.shared.canOpenURL(requestUrl) {
                        UIApplication.shared.open(requestUrl)
                    }
                }
            } else {
                decisionHandler(.cancel)
                if navigationAction.request.url?.scheme == "tel"
                    || navigationAction.request.url?.scheme == "mailto"
                {
                    if UIApplication.shared.canOpenURL(requestUrl) {
                        UIApplication.shared.open(requestUrl)
                    }
                }
            }
        } else {
            decisionHandler(.cancel)
        }

    }
    // Handle javascript: `window.alert(message: String)`
    func webView(
        _ webView: WKWebView,
        runJavaScriptAlertPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping () -> Void
    ) {

        // Set the message as the UIAlertController message
        let alert = UIAlertController(
            title: nil,
            message: message,
            preferredStyle: .alert
        )

        // Add a confirmation action “OK”
        let okAction = UIAlertAction(
            title: "OK",
            style: .default,
            handler: { _ in
                // Call completionHandler
                completionHandler()
            }
        )
        alert.addAction(okAction)

        // Display the NSAlert
        present(alert, animated: true, completion: nil)
    }
    // Handle javascript: `window.confirm(message: String)`
    func webView(
        _ webView: WKWebView,
        runJavaScriptConfirmPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping (Bool) -> Void
    ) {

        // Set the message as the UIAlertController message
        let alert = UIAlertController(
            title: nil,
            message: message,
            preferredStyle: .alert
        )

        // Add a confirmation action “Cancel”
        let cancelAction = UIAlertAction(
            title: "Cancel",
            style: .cancel,
            handler: { _ in
                // Call completionHandler
                completionHandler(false)
            }
        )

        // Add a confirmation action “OK”
        let okAction = UIAlertAction(
            title: "OK",
            style: .default,
            handler: { _ in
                // Call completionHandler
                completionHandler(true)
            }
        )
        alert.addAction(cancelAction)
        alert.addAction(okAction)

        // Display the NSAlert
        present(alert, animated: true, completion: nil)
    }
    // Handle javascript: `window.prompt(prompt: String, defaultText: String?)`
    func webView(
        _ webView: WKWebView,
        runJavaScriptTextInputPanelWithPrompt prompt: String,
        defaultText: String?,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping (String?) -> Void
    ) {

        // Set the message as the UIAlertController message
        let alert = UIAlertController(
            title: nil,
            message: prompt,
            preferredStyle: .alert
        )

        // Add a confirmation action “Cancel”
        let cancelAction = UIAlertAction(
            title: "Cancel",
            style: .cancel,
            handler: { _ in
                // Call completionHandler
                completionHandler(nil)
            }
        )

        // Add a confirmation action “OK”
        let okAction = UIAlertAction(
            title: "OK",
            style: .default,
            handler: { _ in
                // Call completionHandler with Alert input
                if let input = alert.textFields?.first?.text {
                    completionHandler(input)
                }
            }
        )

        alert.addTextField { textField in
            textField.placeholder = defaultText
        }
        alert.addAction(cancelAction)
        alert.addAction(okAction)

        // Display the NSAlert
        present(alert, animated: true, completion: nil)
    }

    func webView(
        _ webView: WKWebView, navigationAction: WKNavigationAction,
        didBecome download: WKDownload
    ) {
        download.delegate = self
    }

    func download(
        _ download: WKDownload, decideDestinationUsing response: URLResponse,
        suggestedFilename: String,
        completionHandler: @escaping (URL?) -> Void
    ) {

        let fileUrl = getDownloadDir().appendingPathComponent(suggestedFilename)

        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: fileUrl.path) {
            do {
                try fileManager.removeItem(at: fileUrl)
            } catch {
                print("failed to remove \(fileUrl)")
                completionHandler(nil)
                return
            }

        }

        downloads[download] = fileUrl

        completionHandler(fileUrl)
    }

    func download(
        _ download: WKDownload, didFailWithError error: Error, resumeData: Data?
    ) {
        if let fileUrl = downloads[download] {
            print("download failed for \(fileUrl.absoluteString)")
            downloads.removeValue(forKey: download)
        } else {
            print("unknown download failed")
        }
    }

    func downloadDidFinish(_ download: WKDownload) {
        if downloads[download] == nil {
            print("downloadDidFinish with unknown download")
            return
        }

        let fileUrl = downloads[download]!
        downloads.removeValue(forKey: download)

        let controller = UIActivityViewController(
            activityItems: [fileUrl], applicationActivities: nil)
        present(controller, animated: true)
    }
}
