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
let adaptiveUIStyle = true     // iOS 15+ only. Change app theme on the fly to dark/light related to WebView background color.
let overrideStatusBar = false   // iOS 13-14 only. if you don't support dark/light system theme.
let statusBarTheme = "dark"    // dark / light, related to override option.

func getRootUrl() -> URL {
    return URL(string:  UserDefaults.standard.bool(forKey: "USE_PREVIEW_BUILD") ? "https://cloudpilot-emu.github.io/app-preview/index.html" : "https://cloudpilot-emu.github.io/app/index.html")!
}
