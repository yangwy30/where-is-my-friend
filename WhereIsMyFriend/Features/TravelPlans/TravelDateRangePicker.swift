import SwiftUI

struct TravelDateRangeSelection: Equatable {
    var start: String
    var end: String?

    mutating func select(_ day: String) {
        if end != nil { start = day; end = nil }
        else if day < start { end = start; start = day }
        else { end = day }
    }

    var dayCount: Int? {
        guard let end, let first = PersonalTravelPlan.parseDay(start), let last = PersonalTravelPlan.parseDay(end) else { return nil }
        return Int(last.timeIntervalSince(first) / 86400) + 1
    }

    static func label(start: String, end: String) -> String {
        let first = TripDay(value: start).label, last = TripDay(value: end).label
        if start == end { return "\(first), \(start.prefix(4))" }
        if start.prefix(4) == end.prefix(4) { return "\(first) – \(last), \(end.prefix(4))" }
        return "\(first), \(start.prefix(4)) – \(last), \(end.prefix(4))"
    }
}

struct TravelDateRangePicker: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selection: TravelDateRangeSelection
    @State private var month: Date
    private let minimumDay: String?
    private let maximumStart: String?
    private let maximumSpan: Int?
    private let onSelect: (String, String) -> Void

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = .current
        calendar.timeZone = .gmt
        calendar.firstWeekday = Calendar.current.firstWeekday
        return calendar
    }

    init(startDay: String, endDay: String, timeZone: String? = nil,
         futurePlansOnly: Bool = true, onSelect: @escaping (String, String) -> Void) {
        let start = PersonalTravelPlan.parseDay(startDay) ?? Date()
        let validStart = TripDay(start, timeZone: .gmt).value
        self._selection = State(initialValue: TravelDateRangeSelection(start: validStart, end: max(validStart, endDay)))
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = .gmt
        self._month = State(initialValue: calendar.date(from: calendar.dateComponents([.year, .month], from: start)) ?? start)
        let today = TripDay(Date(), timeZone: TimeZone(identifier: timeZone ?? "") ?? .current).value
        self.minimumDay = futurePlansOnly ? min(today, validStart) : nil
        self.maximumStart = futurePlansOnly ? (PersonalTravelPlan.parseDay(today).map { TripDay($0.addingTimeInterval(730 * 86400), timeZone: .gmt).value } ?? nil) : nil
        self.maximumSpan = futurePlansOnly ? 366 : nil
        self.onSelect = onSelect
    }

    private var monthTitle: String {
        let formatter = DateFormatter(); formatter.locale = .current; formatter.calendar = calendar; formatter.timeZone = .gmt
        formatter.setLocalizedDateFormatFromTemplate("MMMM yyyy")
        return formatter.string(from: month)
    }

    private var cells: [Date?] {
        let offset = (calendar.component(.weekday, from: month) - calendar.firstWeekday + 7) % 7
        let count = calendar.range(of: .day, in: .month, for: month)?.count ?? 30
        return Array(repeating: nil, count: offset) + (0..<count).map { calendar.date(byAdding: .day, value: $0, to: month) }
    }

    private func canSelect(_ day: String) -> Bool {
        if let minimumDay, day < minimumDay { return false }
        if selection.end != nil || day < selection.start {
            if let maximumStart, day > maximumStart { return false }
        }
        if selection.end == nil, let maximumSpan,
           let start = PersonalTravelPlan.parseDay(selection.start), let date = PersonalTravelPlan.parseDay(day),
           abs(date.timeIntervalSince(start)) > Double(maximumSpan) * 86400 { return false }
        return true
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    VStack(spacing: 8) {
                        if let end = selection.end {
                            Text(TravelDateRangeSelection.label(start: selection.start, end: end))
                                .font(.title3.weight(.semibold)).multilineTextAlignment(.center)
                            Text("Tap a date to choose a new start.").font(.subheadline).foregroundStyle(WIFTheme.secondaryText)
                        } else {
                            Text("Choose an end date").font(.title3.weight(.semibold))
                            Text(TripDay(value: selection.start).label).font(.subheadline).foregroundStyle(WIFTheme.fresh)
                        }
                    }
                    .padding(.horizontal, 20).accessibilityIdentifier("dateRangeSummary")

                    VStack(spacing: 12) {
                        HStack {
                            Button { moveMonth(-1) } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44).contentShape(Rectangle()) }
                                .accessibilityLabel("Previous month").accessibilityIdentifier("rangePreviousMonth")
                            Spacer(minLength: 0)
                            Text(monthTitle).font(.headline).accessibilityIdentifier("rangeMonthTitle")
                            Spacer(minLength: 0)
                            Button { moveMonth(1) } label: { Image(systemName: "chevron.right").frame(width: 44, height: 44).contentShape(Rectangle()) }
                                .accessibilityLabel("Next month").accessibilityIdentifier("rangeNextMonth")
                        }
                        .buttonStyle(.plain).foregroundStyle(WIFTheme.fresh)
                        HStack(spacing: 0) {
                            ForEach(0..<7) { index in
                                Text(calendar.veryShortStandaloneWeekdaySymbols[(calendar.firstWeekday - 1 + index) % 7])
                                    .font(.caption).foregroundStyle(WIFTheme.secondaryText).frame(maxWidth: .infinity)
                            }
                        }.accessibilityHidden(true)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 6) {
                            ForEach(cells.indices, id: \.self) { index in
                                if let date = cells[index] { dayButton(date) }
                                else { Color.clear.frame(height: 44).accessibilityHidden(true) }
                            }
                        }
                    }
                    .padding(.horizontal, 10).padding(.vertical, 14)
                    .background(WIFTheme.surface, in: RoundedRectangle(cornerRadius: 24))
                    .padding(.horizontal, 8)

                    if let count = selection.dayCount {
                        Text("\(count) days selected").font(.subheadline).foregroundStyle(WIFTheme.fresh)
                    }
                    Button {
                        guard let end = selection.end else { return }
                        onSelect(selection.start, end); dismiss()
                    } label: { Text("Use these dates") }
                        .buttonStyle(TravelPrimaryButtonStyle()).padding(.horizontal, 20)
                        .disabled(selection.end == nil).opacity(selection.end == nil ? 0.45 : 1)
                        .accessibilityIdentifier("confirmDateRange")
                }
                .padding(.vertical, 24)
            }
            .wifAmbientBackground().foregroundStyle(WIFTheme.primaryText)
            .navigationTitle("Choose dates").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
        .tint(WIFTheme.fresh).accessibilityIdentifier("dateRangePicker")
    }

    private func moveMonth(_ offset: Int) {
        if let next = calendar.date(byAdding: .month, value: offset, to: month),
           (1...9998).contains(calendar.component(.year, from: next)) { month = next }
    }

    private func dayButton(_ date: Date) -> some View {
        let day = TripDay(date, timeZone: .gmt).value
        let first = day == selection.start
        let last = day == selection.end
        let inside = selection.end.map { day >= selection.start && day <= $0 } ?? first
        let selectable = canSelect(day)
        return Button { selection.select(day) } label: {
            Text(calendar.component(.day, from: date), format: .number)
                .font(.body.weight(first || last ? .semibold : .regular))
                .lineLimit(1).minimumScaleFactor(0.7)
                .foregroundStyle(first || last ? WIFTheme.canvas : WIFTheme.primaryText)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background {
                    ZStack {
                        if inside, selection.end != nil {
                            UnevenRoundedRectangle(topLeadingRadius: first ? 22 : 0, bottomLeadingRadius: first ? 22 : 0,
                                bottomTrailingRadius: last ? 22 : 0, topTrailingRadius: last ? 22 : 0)
                                .fill(WIFTheme.fresh.opacity(0.12))
                        }
                        if first || last { Circle().fill(WIFTheme.fresh).frame(width: 40, height: 40) }
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain).disabled(!selectable).opacity(selectable ? 1 : 0.3)
        .accessibilityLabel(day)
        .accessibilityValue(first ? String(localized: "Start date") : last ? String(localized: "End date") : inside ? String(localized: "In selected range") : "")
        .accessibilityAddTraits(inside ? .isSelected : [])
        .accessibilityIdentifier("rangeDay-\(day)")
    }
}
