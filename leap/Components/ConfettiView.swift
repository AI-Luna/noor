//
//  ConfettiView.swift
//  leap
//
//  Simple falling confetti for celebration modals
//

import SwiftUI

// Confetti color scheme variants
enum ConfettiStyle {
    case mixed      // original multi-color
    case green      // habit completion
    case pink       // journey mission completion
    
    var colors: [Color] {
        switch self {
        case .mixed:
            return [
                Color.noorPink,
                Color(hex: "FFD93D"),
                Color(hex: "6BCB77"),
                Color(hex: "4D96FF"),
                Color.noorCoral,
            ]
        case .green:
            return [
                Color.noorSuccess,
                Color(hex: "22C55E"),
                Color(hex: "4ADE80"),
                Color(hex: "34D399"),
                Color(hex: "6EE7B7"),
            ]
        case .pink:
            return [
                Color.noorAccent,
                Color.noorPink,
                Color.noorRoseGold,
                Color(hex: "FB7185"),
                Color(hex: "F472B6"),
            ]
        }
    }
}

struct ConfettiView: View {
    var isActive: Bool = true
    var pieceCount: Int = 120
    var duration: Double = 4.0
    var style: ConfettiStyle = .mixed
    @State private var hasStartedFalling = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(0..<pieceCount, id: \.self) { i in
                    ConfettiPiece(index: i, width: geo.size.width, height: geo.size.height, isFallen: hasStartedFalling, duration: duration, colors: style.colors)
                }
            }
            .allowsHitTesting(false)
            .onChange(of: isActive) { _, active in
                if active && !hasStartedFalling {
                    hasStartedFalling = true
                }
            }
            .onAppear {
                if isActive {
                    hasStartedFalling = true
                }
            }
        }
    }
}

private struct ConfettiPiece: View {
    let index: Int
    let width: CGFloat
    let height: CGFloat
    let isFallen: Bool
    let duration: Double
    let colors: [Color]

    private var seed: Double {
        Double(index) * 0.1
    }

    private var startX: CGFloat {
        CGFloat((seed * 97).truncatingRemainder(dividingBy: 1)) * width
    }

    private var endX: CGFloat {
        startX + CGFloat((seed * 31).truncatingRemainder(dividingBy: 1) - 0.5) * 180
    }

    private var color: Color {
        colors[index % colors.count]
    }

    private var delay: Double {
        Double((index % 15)) * 0.06
    }

    // Bigger pieces: mix of medium and large for a fuller, more visible burst
    private var size: CGFloat {
        let base = CGFloat(8 + (index % 10))  // 8–17 pt
        return index % 5 == 0 ? base * 1.4 : base  // every 5th piece extra large
    }

    var body: some View {
        RoundedRectangle(cornerRadius: index % 2 == 0 ? 3 : size / 2)
            .fill(color)
            .frame(width: size, height: index % 2 == 0 ? size * 1.5 : size)
            .shadow(color: color.opacity(0.6), radius: 1)
            .rotationEffect(.degrees(Double(index % 360)))
            .position(x: isFallen ? endX : startX, y: isFallen ? height + 80 : -30)
            .animation(
                isFallen
                    ? .easeIn(duration: duration).delay(delay)
                    : .default,
                value: isFallen
            )
    }
}

#Preview("Mixed") {
    ZStack {
        Color.gray.opacity(0.3)
        ConfettiView(isActive: true, style: .mixed)
    }
    .frame(height: 400)
}

#Preview("Green - Habits") {
    ZStack {
        Color.noorBackground
        ConfettiView(isActive: true, style: .green)
    }
    .frame(height: 400)
}

#Preview("Pink - Journey") {
    ZStack {
        Color.noorBackground
        ConfettiView(isActive: true, style: .pink)
    }
    .frame(height: 400)
}
