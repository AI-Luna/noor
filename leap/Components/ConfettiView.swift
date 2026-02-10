//
//  ConfettiView.swift
//  leap
//
//  Simple falling confetti for celebration modals
//

import SwiftUI

struct ConfettiView: View {
    var isActive: Bool = true
    var pieceCount: Int = 50
    var duration: Double = 3.0
    @State private var hasStartedFalling = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(0..<pieceCount, id: \.self) { i in
                    ConfettiPiece(index: i, width: geo.size.width, height: geo.size.height, isFallen: hasStartedFalling, duration: duration)
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

    private static let colors: [Color] = [
        Color.noorPink,
        Color(hex: "FFD93D"),
        Color(hex: "6BCB77"),
        Color(hex: "4D96FF"),
        Color.noorCoral,
    ]

    private var seed: Double {
        Double(index) * 0.1
    }

    private var startX: CGFloat {
        CGFloat((seed * 97).truncatingRemainder(dividingBy: 1)) * width
    }

    private var endX: CGFloat {
        startX + CGFloat((seed * 31).truncatingRemainder(dividingBy: 1) - 0.5) * 120
    }

    private var color: Color {
        Self.colors[index % Self.colors.count]
    }

    private var delay: Double {
        Double((index % 10)) * 0.08
    }

    private var size: CGFloat {
        CGFloat(4 + (index % 6))
    }

    var body: some View {
        RoundedRectangle(cornerRadius: index % 2 == 0 ? 2 : size / 2)
            .fill(color)
            .frame(width: size, height: index % 2 == 0 ? size * 1.5 : size)
            .rotationEffect(.degrees(Double(index % 360)))
            .position(x: isFallen ? endX : startX, y: isFallen ? height + 50 : -20)
            .animation(
                isFallen
                    ? .easeIn(duration: duration).delay(delay)
                    : .default,
                value: isFallen
            )
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.3)
        ConfettiView(isActive: true)
    }
    .frame(height: 400)
}
