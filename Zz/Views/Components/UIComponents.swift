import SwiftUI

// MARK: - Loading Spinner

struct LoadingSpinner: View {
    @State private var rotation: Double = 0
    var size: CGFloat = 16
    var lineWidth: CGFloat = 1.5

    var body: some View {
        Circle()
            .trim(from: 0.2, to: 1.0)
            .stroke(
                AngularGradient(
                    gradient: Gradient(colors: [Color.primary.opacity(0), Color.primary.opacity(0.6)]),
                    center: .center
                ),
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
            )
            .frame(width: size, height: size)
            .rotationEffect(.degrees(rotation))
            .animation(
                .linear(duration: 0.8)
                .repeatForever(autoreverses: false),
                value: rotation
            )
            .onAppear { rotation = 360 }
    }
}

// MARK: - Pulsing Dot

struct PulsingDot: View {
    @State private var isAnimating = false
    var size: CGFloat = 6

    var body: some View {
        Circle()
            .fill(Color.primary.opacity(0.5))
            .frame(width: size, height: size)
            .scaleEffect(isAnimating ? 1.3 : 0.8)
            .opacity(isAnimating ? 0.4 : 0.8)
            .animation(
                .easeInOut(duration: 0.8)
                .repeatForever(autoreverses: true),
                value: isAnimating
            )
            .onAppear { isAnimating = true }
    }
}

// MARK: - Input Control Warning Banner

struct InputControlBanner: View {
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 11))
                .scaleEffect(pulse ? 1.1 : 1.0)

            Text("AI controlling input — don't move mouse/keyboard")
                .font(.system(size: 10, weight: .medium))
        }
        .foregroundColor(.primary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color.red.opacity(0.12))
                .overlay(
                    Capsule().stroke(Color.red.opacity(0.2), lineWidth: 0.5)
                )
        )
        .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: pulse)
        .onAppear { pulse = true }
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
