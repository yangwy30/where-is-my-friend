import SwiftUI

public struct PermissionRequestView: View {
    public var onCompleted: () -> Void

    public var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("🔒")
                .font(.system(size: 80))

            Text("Location & Notifications")
                .font(.title.bold())

            Text("We only request city-level location to update your friend status. We never share your exact GPS coordinates.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 32)

            Spacer()

            VStack(spacing: 12) {
                Button {
                    LocationService.shared.requestAlwaysAuthorization()
                    NotificationService.shared.requestNotificationPermission()
                    onCompleted()
                } label: {
                    Text("Enable Permissions")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.blue)
                        .cornerRadius(12)
                }

                Button("Skip for Now") {
                    onCompleted()
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
            }
            .padding(.horizontal)
        }
    }
}
