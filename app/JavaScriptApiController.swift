import WebKit

class JavaScriptApiController :  NSObject, WKScriptMessageHandlerWithReply {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage, replyHandler: @MainActor (Any?, String?) -> Void) {
        
        guard let request = message.body as? NSDictionary else {
            replyHandler(nil, "bad API request: not an object")
            return
        }
        
        guard let method = request.object(forKey: "method") as? NSString else {
            replyHandler(nil, "bad API request: missing method")
            return
        }
        
        switch (method) {
        case "netOpenSession":
            replyHandler(NSNumber(value: net_openSession()), nil)
            
        case "netCloseSession":
            guard let sessionId = request.object(forKey: "sessionId") as? NSNumber else {
                replyHandler(nil, "invalid or missing session ID")
                return
            }
            
            net_closeSession(sessionId.uint32Value)
            replyHandler(nil, nil)
            
        default:
            replyHandler(nil, "invalid method: \(method)")
            return
        }
    }
    
}
