import WebKit

// allowed origin is for what we are sticking to pwa domain
// This should also appear in Info.plist
let allowedOrigins: [String] = ["cloudpilot-emu.github.io"]

// UI options
let displayMode = "standalone"  // standalone / fullscreen.

let rootUrlStable = URL(string: "https://cloudpilot-emu.github.io/app")!
let rootUrlPreview = URL(
    string: "https://cloudpilot-emu.github.io/app-preview")!

func usePreviewBuild() -> Bool {
    return UserDefaults.standard.bool(forKey: "USE_PREVIEW_BUILD")
}

func getRootUrl() -> URL {
    return usePreviewBuild() ? rootUrlPreview : rootUrlStable
}

fileprivate func qualifyKey(_ key: String) -> String {
    return key + (usePreviewBuild() ? "_PREVIEW" : "")
}

func setWorkerRegistered(_ workerRegistered: Bool) {
    UserDefaults.standard.set(workerRegistered, forKey: qualifyKey("WORKER_REGISTERED"))
}

func getWorkerRegistered() -> Bool {
    return UserDefaults.standard.bool(forKey: qualifyKey("WORKER_REGISTERED"))
}

func setWorkerFailed(_ workerFailed: Bool) {
    UserDefaults.standard.set(workerFailed, forKey: qualifyKey("WORKER_FAILED"))
}

func getWorkerFailed() -> Bool {
    return UserDefaults.standard.bool(forKey: qualifyKey("WORKER_FAILED"))
}
