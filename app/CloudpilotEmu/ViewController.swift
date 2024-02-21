import UIKit
import WebKit

var webView: WKWebView! = nil

class ViewController: UIViewController, WKNavigationDelegate, UIDocumentInteractionControllerDelegate {
    
    var documentController: UIDocumentInteractionController?
    func documentInteractionControllerViewControllerForPreview(_ controller: UIDocumentInteractionController) -> UIViewController {
        return self
    }
    
    @IBOutlet weak var loadingView: UIView!
    @IBOutlet weak var progressView: UIProgressView!
    @IBOutlet weak var connectionProblemView: UIImageView!
    @IBOutlet weak var webviewView: UIView!
    
    var htmlIsLoaded = false;
    
    private var themeObservation: NSKeyValueObservation?
    var currentWebViewTheme: UIUserInterfaceStyle = .unspecified
    override var preferredStatusBarStyle : UIStatusBarStyle {
        if #available(iOS 13, *), overrideStatusBar{
            if #available(iOS 15, *) {
                return .default
            } else {
                return statusBarTheme == "dark" ? .lightContent : .darkContent
            }
        }
        return .default
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        initWebView()
        loadRootUrl()
    
        NotificationCenter.default.addObserver(self, selector: #selector(self.keyboardWillHide(_:)), name: UIResponder.keyboardWillHideNotification , object: nil)
        
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        CloudpilotEmu.webView.frame = calcWebviewFrame(webviewView: webviewView)
    }
    
    @objc func keyboardWillHide(_ notification: NSNotification) {
        CloudpilotEmu.webView.setNeedsLayout()
    }
    
    func initWebView() {
        CloudpilotEmu.webView = createWebView(container: webviewView, WKSMH: self, WKND: self, NSO: self, VC: self)
        webviewView.addSubview(CloudpilotEmu.webView);
        
        CloudpilotEmu.webView.uiDelegate = self;
        
        CloudpilotEmu.webView.addObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress), options: .new, context: nil)

        if(pullToRefresh){
            let refreshControl = UIRefreshControl()
            refreshControl.addTarget(self, action: #selector(refreshWebView(_:)), for: UIControl.Event.valueChanged)
            CloudpilotEmu.webView.scrollView.addSubview(refreshControl)
            CloudpilotEmu.webView.scrollView.bounces = true
        }

        if #available(iOS 15.0, *), adaptiveUIStyle {
            themeObservation = CloudpilotEmu.webView.observe(\.underPageBackgroundColor) { [unowned self] webView, _ in
                currentWebViewTheme = CloudpilotEmu.webView.underPageBackgroundColor.isLight() ?? true ? .light : .dark
                self.overrideUIStyle()
            }
        }
    }

    @objc func refreshWebView(_ sender: UIRefreshControl) {
        CloudpilotEmu.webView?.reload()
        sender.endRefreshing()
    }
    
    func overrideUIStyle(toDefault: Bool = false) {
        if #available(iOS 15.0, *), adaptiveUIStyle {
            if (((htmlIsLoaded && !CloudpilotEmu.webView.isHidden) || toDefault) && self.currentWebViewTheme != .unspecified) {
                UIApplication
                    .shared
                    .connectedScenes
                    .flatMap { ($0 as? UIWindowScene)?.windows ?? [] }
                    .first { $0.isKeyWindow }?.overrideUserInterfaceStyle = toDefault ? .unspecified : self.currentWebViewTheme;
            }
        }
    }
    
    @objc func loadRootUrl() {
        CloudpilotEmu.webView.load(URLRequest(url: SceneDelegate.universalLinkToLaunch ?? SceneDelegate.shortcutLinkToLaunch ?? rootUrl))
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!){
        htmlIsLoaded = true
        
        self.setProgress(1.0, true)
        self.animateConnectionProblem(false)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            CloudpilotEmu.webView.isHidden = false
            self.loadingView.isHidden = true
           
            self.setProgress(0.0, false)
            
            self.overrideUIStyle()
        }
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        htmlIsLoaded = false;
        
        if (error as NSError)._code != (-999) {
            self.overrideUIStyle(toDefault: true);

            webView.isHidden = true;
            loadingView.isHidden = false;
            animateConnectionProblem(true);
            
            setProgress(0.05, true);

            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                self.setProgress(0.1, true);
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    self.loadRootUrl();
                }
            }
        }
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {

        if (keyPath == #keyPath(WKWebView.estimatedProgress) &&
                CloudpilotEmu.webView.isLoading &&
                !self.loadingView.isHidden &&
                !self.htmlIsLoaded) {
                    var progress = Float(CloudpilotEmu.webView.estimatedProgress);
                    
                    if (progress >= 0.8) { progress = 1.0; };
                    if (progress >= 0.3) { self.animateConnectionProblem(false); }
                    
                    self.setProgress(progress, true);
        }
    }
    
    func setProgress(_ progress: Float, _ animated: Bool) {
        self.progressView.setProgress(progress, animated: animated);
    }
    
    
    func animateConnectionProblem(_ show: Bool) {
        if (show) {
            self.connectionProblemView.isHidden = false;
            self.connectionProblemView.alpha = 0
            UIView.animate(withDuration: 0.7, delay: 0, options: [.repeat, .autoreverse], animations: {
                self.connectionProblemView.alpha = 1
            })
        }
        else {
            UIView.animate(withDuration: 0.3, delay: 0, options: [], animations: {
                self.connectionProblemView.alpha = 0 // Here you will get the animation you want
            }, completion: { _ in
                self.connectionProblemView.isHidden = true;
                self.connectionProblemView.layer.removeAllAnimations();
            })
        }
    }
        
    deinit {
        CloudpilotEmu.webView.removeObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress))
    }
}

extension UIColor {
    // Check if the color is light or dark, as defined by the injected lightness threshold.
    // Some people report that 0.7 is best. I suggest to find out for yourself.
    // A nil value is returned if the lightness couldn't be determined.
    func isLight(threshold: Float = 0.5) -> Bool? {
        let originalCGColor = self.cgColor

        // Now we need to convert it to the RGB colorspace. UIColor.white / UIColor.black are greyscale and not RGB.
        // If you don't do this then you will crash when accessing components index 2 below when evaluating greyscale colors.
        let RGBCGColor = originalCGColor.converted(to: CGColorSpaceCreateDeviceRGB(), intent: .defaultIntent, options: nil)
        guard let components = RGBCGColor?.components else {
            return nil
        }
        guard components.count >= 3 else {
            return nil
        }

        let brightness = Float(((components[0] * 299) + (components[1] * 587) + (components[2] * 114)) / 1000)
        return (brightness > threshold)
    }
}

extension ViewController: WKScriptMessageHandler {
  func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
  }
}
