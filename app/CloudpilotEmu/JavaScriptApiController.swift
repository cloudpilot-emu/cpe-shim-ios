import WebKit

fileprivate var globalApiController: JavaScriptApiController? = nil

class JavaScriptApiController :  NSObject, WKScriptMessageHandlerWithReply {
    weak var webView: WKWebView?
    weak var networkingUIDelegate: NetworkingUIDelegate?
    
    override init() {
        super.init()
        globalApiController = self
                
        let rpcResultCb: net_RpcResultCb = {(sessionId, data, len, context) in
            let rpcData = Array(UnsafeBufferPointer(start: data, count: len)) as NSArray
            
            DispatchQueue.main.async() {
                globalApiController?.dispatchCall(type: "netRpcResult", payload: ["rpcData": rpcData, "sessionId": sessionId as NSNumber])
            }
        }
        
        net_setRpcCallback(rpcResultCb, nil)
    }
    
    func setNetworkingUIDelegate(_ delegate: NetworkingUIDelegate) {
        networkingUIDelegate = delegate
    }
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage, replyHandler: @MainActor (Any?, String?) -> Void) {

        guard let request = message.body as? NSDictionary else {
            replyHandler(nil, "bad API request: not an object")
            return
        }
        
        guard let type = request.object(forKey: "type") as? NSString else {
            replyHandler(nil, "bad API request: missing type")
            return
        }
        
        switch (type) {
        case "netOpenSession":
            networkingUIDelegate?.notifyNetworkSessionStart()
            replyHandler(NSNumber(value: net_openSession()), nil)
            
        case "netCloseSession":
            guard let sessionId = request.object(forKey: "sessionId") as? NSNumber else {
                replyHandler(nil, "invalid or missing session ID")
                return
            }
            
            networkingUIDelegate?.notifyNetworkSessionEnd()
            
            net_closeSession(sessionId.uint32Value)
            replyHandler(nil, nil)
            
        case "netDispatchRpc":
            guard let sessionId = request.object(forKey: "sessionId") as? NSNumber else {
                replyHandler(nil, "invalid or missing session ID")
                return
            }
            
            guard let rpcData = request.object(forKey: "rpcData") as? NSArray as? [UInt8] else {
                replyHandler(nil, "invalid or missing RPC payload")
                return
            }
        
            let dispatchRpcResult = net_dispatchRpc(sessionId.uint32Value, rpcData, rpcData.count) as NSNumber
            replyHandler(dispatchRpcResult, nil)
            
        default:
            replyHandler(nil, "invalid type: \(type)")
            return
        }
    }
    
    private func dispatchCall(type: String, payload: [String: Any] = [:]) {
        guard let webView = webView else {
            return
        }
        
        var payload = payload
        payload["type"] = type
        
        webView.callAsyncJavaScript(
            "window.__cpeCallFromNative ? window.__cpeCallFromNative(payload) : console.error('unable to dispatch native call')",
            arguments: ["payload": payload], in: nil, in: WKContentWorld.page, completionHandler: nil)
    }
}
