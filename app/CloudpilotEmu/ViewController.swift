import UIKit
import WebKit
import Toast_Swift

var webView: WKWebView! = nil
var javascriptApiController: JavaScriptApiController! = nil

class ViewController: UIViewController, WKNavigationDelegate, UIDocumentInteractionControllerDelegate, NetworkingUIDelegate{
    enum LoadingMode {
        case defaultCachePolicy
        case forceCache
    }
    
    private var documentController: UIDocumentInteractionController?
    func documentInteractionControllerViewControllerForPreview(_ controller: UIDocumentInteractionController) -> UIViewController {
        return self
    }
    
    @IBOutlet weak var loadingView: UIView!
    @IBOutlet weak var progressView: UIProgressView!
    @IBOutlet weak var connectionProblemView: UIImageView!
    @IBOutlet weak var webviewView: UIView!
    
    private var htmlIsLoaded = false
    private var isAnimatingConnectionProblem = false
    private var currentRoot = ""
    private var loadingMode = LoadingMode.defaultCachePolicy
    
    override func viewDidLoad() {
        super.viewDidLoad()
        ToastManager.shared.isQueueEnabled = false
        initWebView()
        reloadWebview()
    
        NotificationCenter.default.addObserver(self, selector: #selector(self.keyboardWillHide(_:)), name: UIResponder.keyboardWillHideNotification , object: nil)
        
        NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: OperationQueue.main, using: {notification in
            self.reloadWebview()}
        )
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        CloudpilotEmu.webView.frame = calcWebviewFrame(webviewView: webviewView)
    }
    
    @objc func keyboardWillHide(_ notification: NSNotification) {
        CloudpilotEmu.webView.setNeedsLayout()
    }
    
    func initWebView() {
        let (webView, javascriptApiController) = createWebView(container: webviewView, WKND: self, NSO: self)
        javascriptApiController.setNetworkingUIDelegate(self)
        CloudpilotEmu.webView = webView
        CloudpilotEmu.javascriptApiController = javascriptApiController
        
        webviewView.addSubview(CloudpilotEmu.webView);
        
        CloudpilotEmu.webView.uiDelegate = self
        CloudpilotEmu.webView.isHidden = true
        CloudpilotEmu.webView.addObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress), options: .new, context: nil)
    }
    
    
    func reloadWebview(force: Bool = false, loadingMode: LoadingMode = LoadingMode.defaultCachePolicy) {
        let newRoot = getRootUrl()
        
        if (currentRoot == newRoot.absoluteString && !force) {
            return
        }
        currentRoot = newRoot.absoluteString
        
        switch (loadingMode) {
        case LoadingMode.defaultCachePolicy:
            CloudpilotEmu.webView.load(URLRequest(url: newRoot, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 3))
            
        case LoadingMode.forceCache:
            CloudpilotEmu.webView.load(URLRequest(url: newRoot, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 10))
        }

        self.loadingMode = loadingMode
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!){
        htmlIsLoaded = true
        
        self.setProgress(1.0, true)
        self.animateConnectionProblem(false)
                
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            CloudpilotEmu.webView.isHidden = false
            self.loadingView.isHidden = true
           
            self.setProgress(0.0, false)
        }
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        htmlIsLoaded = false;
        
        if ((error as NSError).code == -999) {
            return
        }

        webView.isHidden = true;
        loadingView.isHidden = false;
        
        if (loadingMode == LoadingMode.defaultCachePolicy) {
            DispatchQueue.main.async {
                self.reloadWebview(force: true, loadingMode: LoadingMode.forceCache)
            }
        } else {
            animateConnectionProblem(true);
            setProgress(0.0, true);
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                self.reloadWebview(force: true);
            }
        }
    }
    
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        if (!htmlIsLoaded) {
            return
        }
            
        CloudpilotEmu.webView.isHidden = true
        self.loadingView.isHidden = false
        self.htmlIsLoaded = false
        self.animateConnectionProblem(false)
        self.setProgress(0.0, false)
        
        net_closeAllSessions()
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
            if (isAnimatingConnectionProblem) {
                return
            }
            isAnimatingConnectionProblem = true
            
            self.connectionProblemView.isHidden = false;
            self.connectionProblemView.alpha = 0
            UIView.animate(withDuration: 0.7, delay: 0, options: [.repeat, .autoreverse], animations: {
                self.connectionProblemView.alpha = 1
            })
        }
        else {
            isAnimatingConnectionProblem = false
            UIView.animate(withDuration: 0.3, delay: 0, options: [], animations: {
                self.connectionProblemView.alpha = 0 // Here you will get the animation you want
            }, completion: { _ in
                self.connectionProblemView.isHidden = true;
                self.connectionProblemView.layer.removeAllAnimations();
            })
        }
    }
    
    func notifyNetworkSessionStart() {
        view.hideAllToasts()
        
        view.makeToast("Network Session started", duration: 1.5, point: toastPosition(), title: nil, image: nil, completion: nil)
    }
    
    func notifyNetworkSessionEnd() {
        view.hideAllToasts()
        view.makeToast("Network Session closed", duration: 1.5, point: toastPosition(), title: nil, image: nil, completion: nil)
    }
    
    func querySessionConsent(onAllow: @escaping () -> Void, onDeny: @escaping () -> Void) {
        let alert = UIAlertController(title: "Network access", message: "PalmOS is trying to access the network.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default){ _ in onAllow() })
        alert.addAction(UIAlertAction(title: "Don't Allow", style: .cancel){ _ in onDeny() })
        
        self.present(alert, animated: true)
    }
    
    private func toastPosition() -> CGPoint {
        return CGPoint(x: self.view.bounds.size.width / 2.0, y: self.view.bounds.size.height / 4 * 3)
    }
            
    deinit {
        CloudpilotEmu.webView.removeObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress))
    }
}
