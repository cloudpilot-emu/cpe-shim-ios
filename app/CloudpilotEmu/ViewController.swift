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
    
    var htmlIsLoaded = false
    var isAnimatingConnectionProblem = false
    var currentRoot = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
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
        CloudpilotEmu.webView = createWebView(container: webviewView, WKSMH: self, WKND: self, NSO: self, VC: self)
        webviewView.addSubview(CloudpilotEmu.webView);
        
        CloudpilotEmu.webView.uiDelegate = self;
        CloudpilotEmu.webView.isHidden = true
        CloudpilotEmu.webView.addObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress), options: .new, context: nil)
    }
    
    
    func reloadWebview(force: Bool = false) {
        let newRoot = getRootUrl()
        
        if (currentRoot == newRoot.absoluteString && !force) {
            return
        }
        currentRoot = newRoot.absoluteString
        
        CloudpilotEmu.webView.load(URLRequest(url: getRootUrl(), cachePolicy: force ? .returnCacheDataElseLoad : .useProtocolCachePolicy))
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
        
        if (error as NSError)._code != (-999) {
            webView.isHidden = true;
            loadingView.isHidden = false;
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
        
    deinit {
        CloudpilotEmu.webView.removeObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress))
    }
}

extension ViewController: WKScriptMessageHandlerWithReply {
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) async -> (Any?, String?) {
        return (nil, nil)
    }

}
