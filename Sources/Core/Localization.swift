import Foundation

private final class CoreLocalizationToken {}

public func L(_ key: String) -> String {
    // Gather candidate bundles: Main app, framework token, and SPM resource bundles
    var bundles: [Bundle] = [Bundle.main, Bundle(for: CoreLocalizationToken.self)]
    
    if let resourcePath = Bundle.main.resourcePath,
       let items = try? FileManager.default.contentsOfDirectory(atPath: resourcePath) {
        for item in items where item.hasSuffix(".bundle") {
            let bundlePath = (resourcePath as NSString).appendingPathComponent(item)
            if let subBundle = Bundle(path: bundlePath) {
                bundles.append(subBundle)
            }
        }
    }

    // 1. Try standard system locale lookup across all bundles
    for bundle in bundles {
        let val = bundle.localizedString(forKey: key, value: nil, table: nil)
        if val != key { return val }
    }

    // 2. Force explicit fallback directly into `en.lproj`
    for bundle in bundles {
        if let enPath = bundle.path(forResource: "en", ofType: "lproj"),
           let enBundle = Bundle(path: enPath) {
            let val = enBundle.localizedString(forKey: key, value: nil, table: nil)
            if val != key { return val }
        }
    }

    return key
}

public func L(_ key: String, _ args: CVarArg...) -> String {
    let format = L(key)
    return String(format: format, locale: Locale.current, arguments: args)
}
