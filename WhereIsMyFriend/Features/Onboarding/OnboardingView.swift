import SwiftUI

public struct OnboardingView: View {
    @AppStorage("onboardingCompleted") private var onboardingCompleted = false
    @State private var currentPage = 0

    public var body: some View {
        VStack {
            TabView(selection: $currentPage) {
                onboardingCard(
                    emoji: "📍",
                    title: "Where's My Friend",
                    description: "Know which city your friends are in around the world."
                ).tag(0)

                onboardingCard(
                    emoji: "🔋",
                    title: "Battery Friendly",
                    description: "Uses Significant Location Changes to update city location automatically without draining battery."
                ).tag(1)

                PermissionRequestView(onCompleted: {
                    onboardingCompleted = true
                }).tag(2)
            }
            .tabViewStyle(.page)

            if currentPage < 2 {
                Button {
                    withAnimation { currentPage += 1 }
                } label: {
                    Text("Next")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.blue)
                        .cornerRadius(12)
                }
                .padding()
            }
        }
    }

    private func onboardingCard(emoji: String, title: String, description: String) -> some View {
        VStack(spacing: 20) {
            Spacer()
            Text(emoji)
                .font(.system(size: 80))
            Text(title)
                .font(.largeTitle.bold())
            Text(description)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 32)
            Spacer()
        }
    }
}
