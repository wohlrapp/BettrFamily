import SwiftUI

struct LaunchScreenView: View {
    var body: some View {
        ZStack {
            // Green gradient background matching the icon
            LinearGradient(
                colors: [
                    Color(red: 0.20, green: 0.68, blue: 0.37),
                    Color(red: 0.28, green: 0.82, blue: 0.44)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                // Family silhouette drawn with SwiftUI shapes
                FamilySilhouette()
                    .fill(.white)
                    .frame(width: 160, height: 180)

                Text("BettrFamily")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("Zusammen besser")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
    }
}

/// SwiftUI Shape that draws the family sculpture silhouette
struct FamilySilhouette: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        let cx = w / 2

        // Parent 1 head (top-left)
        let p1x = cx - w * 0.15
        let p1y = h * 0.12
        let phr = w * 0.11
        path.addEllipse(in: CGRect(x: p1x - phr, y: p1y - phr, width: phr * 2, height: phr * 2))

        // Parent 2 head (top-right)
        let p2x = cx + w * 0.15
        let p2y = h * 0.12
        path.addEllipse(in: CGRect(x: p2x - phr, y: p2y - phr, width: phr * 2, height: phr * 2))

        // Left arm curve
        path.move(to: CGPoint(x: p1x, y: p1y + phr * 0.8))
        path.addCurve(
            to: CGPoint(x: cx, y: h * 0.82),
            control1: CGPoint(x: cx - w * 0.48, y: h * 0.25),
            control2: CGPoint(x: cx - w * 0.40, y: h * 0.75)
        )

        // Right arm curve (continuing the path)
        path.addCurve(
            to: CGPoint(x: p2x, y: p2y + phr * 0.8),
            control1: CGPoint(x: cx + w * 0.40, y: h * 0.75),
            control2: CGPoint(x: cx + w * 0.48, y: h * 0.25)
        )

        // Close top between parent heads
        path.addLine(to: CGPoint(x: p2x, y: p2y + phr * 0.3))
        path.addCurve(
            to: CGPoint(x: p1x, y: p1y + phr * 0.3),
            control1: CGPoint(x: cx + w * 0.05, y: h * 0.18),
            control2: CGPoint(x: cx - w * 0.05, y: h * 0.18)
        )
        path.closeSubpath()

        // Inner cutout (between the arms) — we'll just draw children on top

        // Child 1 head
        let c1x = cx - w * 0.10
        let c1y = h * 0.44
        let chr = w * 0.075
        path.addEllipse(in: CGRect(x: c1x - chr, y: c1y - chr, width: chr * 2, height: chr * 2))

        // Child 2 head
        let c2x = cx + w * 0.10
        let c2y = h * 0.44
        path.addEllipse(in: CGRect(x: c2x - chr, y: c2y - chr, width: chr * 2, height: chr * 2))

        // Child 1 body
        path.addRoundedRect(in: CGRect(x: c1x - w * 0.03, y: c1y + chr * 0.5, width: w * 0.06, height: h * 0.22), cornerSize: CGSize(width: w * 0.03, height: w * 0.03))

        // Child 2 body
        path.addRoundedRect(in: CGRect(x: c2x - w * 0.03, y: c2y + chr * 0.5, width: w * 0.06, height: h * 0.22), cornerSize: CGSize(width: w * 0.03, height: w * 0.03))

        return path
    }
}

#Preview {
    LaunchScreenView()
}
