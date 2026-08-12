import Foundation

extension Date {
    public var relativeFormatted: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        formatter.locale = Locale.current
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}
