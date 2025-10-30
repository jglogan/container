import Foundation

/// Get the nearest enclosing bundle for a path that refers to a bundle member.
public extension Bundle {
    static func appBundle(memberURL: URL) -> Bundle? {
        let components = memberURL.pathComponents
        for i in stride(from: components.count, to: 0, by: -1) {
            let partialPath = NSString.path(withComponents: Array(components.prefix(i)))
            let url = URL(fileURLWithPath: partialPath)
            if url.pathExtension == "app" {
                return Bundle(url: url)
            }
        }
        return nil
    }
}