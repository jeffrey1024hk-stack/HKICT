import Foundation

// MARK: - Global Localization Helpers

func L(_ key: String) -> String {
    // 1. Try Bundle.module first
    let moduleString = NSLocalizedString(key, bundle: .module, comment: "")
    if moduleString != key { return moduleString }
    
    // 2. Fallback to Bundle.main if running directly in Debug/Xcode
    let mainString = NSLocalizedString(key, bundle: .main, comment: "")
    return mainString
}

func L(_ key: String, _ args: CVarArg...) -> String {
    let format = L(key)
    return String(format: format, locale: Locale.current, arguments: args)
}
