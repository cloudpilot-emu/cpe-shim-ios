protocol NetworkingUIDelegate : AnyObject {
    func notifyNetworkSessionStart()
    func notifyNetworkSessionEnd()
    
    func querySessionConsent(onAllow: @escaping () -> Void, onDeny: @escaping () -> Void)
}
