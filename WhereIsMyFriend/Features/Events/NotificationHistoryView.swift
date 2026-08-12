import SwiftUI

struct NotificationHistoryView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        Group {
            if store.snapshot.colocationEvents.isEmpty {
                ContentUnavailableView {
                    Label("No same-city moments yet", systemImage: "bell.slash")
                } description: {
                    Text("A moment appears after an eligible friend enters your current city.")
                }
            } else {
                List(store.snapshot.colocationEvents.sorted(by: { $0.createdAt > $1.createdAt })) { event in
                    VStack(alignment: .leading, spacing: 6) {
                        Label(event.title, systemImage: "person.2.fill")
                            .font(.headline)
                            .foregroundStyle(WIFTheme.primaryText)
                        Text(event.message)
                            .font(.subheadline)
                            .foregroundStyle(WIFTheme.secondaryText)
                        Text(event.createdAt, style: .relative)
                            .font(.caption)
                            .foregroundStyle(WIFTheme.fresh)
                    }
                    .padding(.vertical, 5)
                }
                .scrollContentBackground(.hidden)
            }
        }
        .background(WIFTheme.canvas)
        .navigationTitle("Same-city moments")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("notificationHistoryScreen")
    }
}

#Preview {
    NavigationStack { NotificationHistoryView() }
        .environmentObject(AppStore())
}
