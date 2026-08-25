import SwiftUI

struct FriendDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: AppStore
    let friend: FriendPresence
    @State private var showsRemoveConfirmation = false
    @State private var showsBlockConfirmation = false
    private let referenceDate = Date()

    private var currentFriend: FriendPresence {
        store.friend(id: friend.id) ?? friend
    }

    private var preference: FriendAccessPreference {
        store.preference(for: friend.id)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                FriendAvatarView(friend: currentFriend, size: 84)
                    .padding(.top, 8)

                Text(currentFriend.displayName)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(WIFTheme.primaryText)
                    .padding(.top, 12)

                Text("@\(currentFriend.username)")
                    .font(.subheadline)
                    .foregroundStyle(WIFTheme.secondaryText)
                    .padding(.top, 3)

                citySurface.padding(.top, 24)

                sectionLabel("Between you two").padding(.top, 24)

                VStack(spacing: 0) {
                    Toggle(isOn: sharesMyCityBinding) {
                        settingLabel("Share my city", note: "\(currentFriend.displayName) can see your latest city")
                    }
                    .tint(WIFTheme.fresh)
                    .padding(15)

                    Divider().overlay(WIFTheme.border).padding(.leading, 15)

                    Toggle(isOn: sameCityAlertBinding) {
                        settingLabel("Same-city alert", note: "Notify me when your cities overlap")
                    }
                    .tint(WIFTheme.fresh)
                    .padding(15)

                    Divider().overlay(WIFTheme.border).padding(.leading, 15)

                    Button(role: .destructive) { showsRemoveConfirmation = true } label: {
                        HStack {
                            settingLabel("Remove friend", note: "Stops sharing both ways")
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption.weight(.semibold))
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(WIFTheme.destructive)
                    .padding(15)
                    .accessibilityIdentifier("removeFriendButton")

                    Divider().overlay(WIFTheme.border).padding(.leading, 15)

                    Button(role: .destructive) { showsBlockConfirmation = true } label: {
                        HStack {
                            settingLabel("Block person", note: "Also removes the friendship and pending requests")
                            Spacer()
                            Image(systemName: "hand.raised.slash.fill").font(.caption.weight(.semibold))
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(WIFTheme.destructive)
                    .padding(15)
                    .accessibilityIdentifier("blockFriendButton")
                }
                .wifGlassSurface(
                    tint: WIFTheme.surface.opacity(0.08),
                    in: RoundedRectangle(cornerRadius: WIFTheme.mediumRadius, style: .continuous)
                )

                Label("No precise location or route history is shared.", systemImage: "hand.raised.fill")
                    .font(.footnote)
                    .foregroundStyle(WIFTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.top, 18)
            }
            .padding(.horizontal, WIFTheme.screenInset)
            .padding(.bottom, 28)
        }
        .wifAmbientBackground()
        .navigationTitle(currentFriend.displayName.components(separatedBy: " ").first ?? currentFriend.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task {
                        await store.setFavorite(
                            friendID: currentFriend.id,
                            isFavorite: !currentFriend.isFavorite
                        )
                    }
                } label: {
                    Image(systemName: currentFriend.isFavorite ? "star.fill" : "star")
                }
                .accessibilityLabel(currentFriend.isFavorite ? "Remove favorite" : "Add favorite")
            }
        }
        .confirmationDialog(
            "Remove \(currentFriend.displayName)?",
            isPresented: $showsRemoveConfirmation,
            titleVisibility: .visible
        ) {
            Button("Remove friend", role: .destructive) {
                Task {
                    await store.removeFriend(id: currentFriend.id)
                    if store.friend(id: currentFriend.id) == nil { dismiss() }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The friendship and per-friend sharing preferences will be removed.")
        }
        .confirmationDialog(
            "Block \(currentFriend.displayName)?",
            isPresented: $showsBlockConfirmation,
            titleVisibility: .visible
        ) {
            Button("Block person", role: .destructive) {
                Task {
                    await store.blockUser(id: currentFriend.id)
                    if store.friend(id: currentFriend.id) == nil { dismiss() }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("They will not be able to invite you or see your city. You can unblock them later in Privacy settings.")
        }
    }

    private var sharesMyCityBinding: Binding<Bool> {
        Binding {
            store.preference(for: currentFriend.id).sharesMyCity
        } set: { newValue in
            var updated = store.preference(for: currentFriend.id)
            updated.sharesMyCity = newValue
            Task { await store.setFriendPreference(updated) }
        }
    }

    private var sameCityAlertBinding: Binding<Bool> {
        Binding {
            store.preference(for: currentFriend.id).sameCityAlertEnabled
        } set: { newValue in
            var updated = store.preference(for: currentFriend.id)
            updated.sameCityAlertEnabled = newValue
            Task { await store.setFriendPreference(updated) }
        }
    }

    private var citySurface: some View {
        VStack(spacing: 12) {
            CityEmblemView(city: currentFriend.city, countryCode: currentFriend.countryCode, size: 84)

            VStack(spacing: 4) {
                Text(currentFriend.cityDisplay)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(WIFTheme.primaryText)
                    .multilineTextAlignment(.center)

                Text(currentFriend.relativeUpdateLongText(at: referenceDate))
                    .font(.subheadline)
                    .foregroundStyle(WIFTheme.secondaryText)
            }

            if currentFriend.freshness(at: referenceDate) == .stale {
                Label("This location is too old for same-city alerts", systemImage: "clock.badge.exclamationmark")
                    .font(.caption)
                    .foregroundStyle(WIFTheme.secondaryText)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .padding(.horizontal, 18)
        .wifGlassSurface(
            tint: WIFTheme.eventBlue.opacity(0.20),
            in: RoundedRectangle(cornerRadius: WIFTheme.largeRadius, style: .continuous)
        )
    }

    private func sectionLabel(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .textCase(.uppercase)
            .tracking(1.1)
            .foregroundStyle(WIFTheme.secondaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 3)
            .padding(.bottom, 8)
    }

    private func settingLabel(_ title: LocalizedStringKey, note: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.body.weight(.semibold)).foregroundStyle(WIFTheme.primaryText)
            Text(note).font(.caption).foregroundStyle(WIFTheme.secondaryText)
        }
    }
}

#Preview {
    NavigationStack { FriendDetailView(friend: MockFriendData.friends[0]) }
        .environmentObject(AppStore())
}
