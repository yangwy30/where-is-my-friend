import SwiftUI

struct SharingView: View {
    @State private var citySharingEnabled = true
    @State private var backgroundUpdatesEnabled = true

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                sharingIllustration

                Text("City changes only")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundStyle(WIFTheme.primaryText)
                    .multilineTextAlignment(.center)
                    .padding(.top, 24)

                Text("Friends see your latest city and update time. Precise coordinates and route history stay out of the product.")
                    .font(.body)
                    .foregroundStyle(WIFTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.top, 10)
                    .padding(.horizontal, 8)

                statusCard
                    .padding(.top, 24)

                VStack(spacing: 0) {
                    Toggle(isOn: $citySharingEnabled) {
                        settingLabel("City sharing", note: "Visible to accepted friends")
                    }
                    .tint(WIFTheme.fresh)
                    .padding(15)

                    Divider().overlay(WIFTheme.border).padding(.leading, 15)

                    Toggle(isOn: $backgroundUpdatesEnabled) {
                        settingLabel("Background updates", note: "Prototype setting — no location is requested")
                    }
                    .tint(WIFTheme.fresh)
                    .padding(15)
                }
                .background(WIFTheme.surface, in: RoundedRectangle(cornerRadius: WIFTheme.mediumRadius))
                .overlay {
                    RoundedRectangle(cornerRadius: WIFTheme.mediumRadius)
                        .stroke(WIFTheme.border, lineWidth: 1)
                }
                .padding(.top, 16)

                Label("You can pause sharing at any time.", systemImage: "hand.raised.fill")
                    .font(.footnote)
                    .foregroundStyle(WIFTheme.secondaryText)
                    .padding(.top, 18)
            }
            .padding(.horizontal, WIFTheme.screenInset)
            .padding(.bottom, 30)
        }
        .background(WIFTheme.canvas)
        .navigationTitle("Sharing")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var sharingIllustration: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 32)
                .fill(WIFTheme.eventGradient)
                .frame(height: 230)

            Circle()
                .stroke(WIFTheme.fresh.opacity(0.32), style: StrokeStyle(lineWidth: 3, dash: [7, 8]))
                .frame(width: 210, height: 135)
                .rotationEffect(.degrees(-11))

            Image(systemName: "location.fill.viewfinder")
                .font(.system(size: 50, weight: .semibold))
                .foregroundStyle(WIFTheme.fresh)
                .symbolRenderingMode(.hierarchical)

            Text("NEW YORK")
                .font(.caption.weight(.semibold))
                .foregroundStyle(WIFTheme.primaryText)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(WIFTheme.surface, in: Capsule())
                .offset(x: 82, y: -75)
        }
        .accessibilityHidden(true)
    }

    private var statusCard: some View {
        HStack(spacing: 12) {
            Image(systemName: citySharingEnabled ? "checkmark.circle.fill" : "pause.circle.fill")
                .font(.title2)
                .foregroundStyle(citySharingEnabled ? WIFTheme.fresh : WIFTheme.secondaryText)

            VStack(alignment: .leading, spacing: 3) {
                Text(citySharingEnabled ? "Sharing is on" : "Sharing is paused")
                    .font(.headline)
                    .foregroundStyle(WIFTheme.primaryText)
                Text(citySharingEnabled ? "New York · updated just now" : "Friends cannot see your city")
                    .font(.subheadline)
                    .foregroundStyle(WIFTheme.secondaryText)
            }

            Spacer()
        }
        .padding(16)
        .background(WIFTheme.freshSurface, in: RoundedRectangle(cornerRadius: WIFTheme.mediumRadius))
    }

    private func settingLabel(_ title: LocalizedStringKey, note: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.body.weight(.semibold)).foregroundStyle(WIFTheme.primaryText)
            Text(note).font(.caption).foregroundStyle(WIFTheme.secondaryText)
        }
    }
}

#Preview {
    NavigationStack {
        SharingView()
    }
}
