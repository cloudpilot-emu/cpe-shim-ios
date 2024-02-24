import WebKit

// allowed origin is for what we are sticking to pwa domain
// This should also appear in Info.plist
let allowedOrigins: [String] = ["cloudpilot-emu.github.io"]


// UI options
let displayMode = "standalone" // standalone / fullscreen.

let rootUrlStable = URL(string: "https://cloudpilot-emu.github.io/app")!
let rootUrlPreview = URL(string: "https://cloudpilot-emu.github.io/app-preview")!

func getRootUrl() -> URL {
    return UserDefaults.standard.bool(forKey: "USE_PREVIEW_BUILD") ? rootUrlPreview : rootUrlStable
}

func getEnableAudioOnStart() -> Bool {
    return UserDefaults.standard.bool(forKey: "enableAudioOnStart")
}

func setEnableAudioOnStart(value: Bool) {
    UserDefaults.standard.set(value, forKey: "enableAudioOnStart")
}
