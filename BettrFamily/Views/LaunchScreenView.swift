import SwiftUI

struct LaunchScreenView: View {
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            Image("LaunchPhoto")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            // Gradient overlay for text readability
            VStack {
                Spacer()
                LinearGradient(
                    colors: [.clear, .black.opacity(0.7)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 200)
            }
            .ignoresSafeArea()

            VStack {
                Spacer()

                Text("BettrFamily")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("Zusammen besser")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.bottom, 60)
            }
        }
    }
}

#Preview {
    LaunchScreenView()
}
