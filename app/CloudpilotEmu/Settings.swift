import WebKit

struct Cookie {
    var name: String
    var value: String
}

let gcmMessageIDKey = "00000000000" // update this with actual ID if using Firebase

// allowed origin is for what we are sticking to pwa domain
// This should also appear in Info.plist
let allowedOrigins: [String] = ["cloudpilot-emu.github.io"]

let platformCookie = Cookie(name: "app-platform", value: "iOS App Store")

// UI options
let displayMode = "standalone" // standalone / fullscreen.
let overrideStatusBar = false   // iOS 13-14 only. if you don't support dark/light system theme.
let statusBarTheme = "dark"    // dark / light, related to override option.

let rootUrlStable = URL(string: "https://cloudpilot-emu.github.io/app")!
let rootUrlPreview = URL(string: "https://cloudpilot-emu.github.io/app-preview")!

func getRootUrl() -> URL {
    return UserDefaults.standard.bool(forKey: "USE_PREVIEW_BUILD") ? rootUrlPreview : rootUrlStable
}
