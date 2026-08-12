import Foundation

extension String {
    /// Converts ISO 3166-1 alpha-2 country code (e.g. "CN", "US") into country flag emoji (e.g. "🇨🇳", "🇺🇸")
    public var countryFlag: String {
        let base: UInt32 = 127397
        return self.uppercased().unicodeScalars.compactMap {
            UnicodeScalar(base + $0.value)
        }.map { String($0) }.joined()
    }
}
