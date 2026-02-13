//
//  ConfettiView.swift
//  leap
//
//  Falling confetti for celebration modals. Optional burst-from-all-sides then paper fall.
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
    /// When true, confetti bursts in from all four edges (fast), then falls down like paper.
    var fromAllSides: Bool = false
    @State private var hasStartedFalling = false
    @State private var burstPhaseDone = false
    @State private var fallPhaseDone = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(0..<pieceCount, id: \.self) { i in
                    ConfettiPiece(
                        index: i,
                        width: geo.size.width,
                        height: geo.size.height,
                        isFallen: fromAllSides ? fallPhaseDone : hasStartedFalling,
                        duration: duration,
                        colors: style.colors,
                        fromAllSides: fromAllSides,
                        burstDone: burstPhaseDone,
                        fallDone: fallPhaseDone
                    )
                }
            }
            .allowsHitTesting(false)
            .onChange(of: isActive) { _, active in
                if active && !hasStartedFalling {
                    if fromAllSides {
                        burstPhaseDone = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                            fallPhaseDone = true
                        }
                    } else {
                        hasStartedFalling = true
                    }
                }
            }
            .onAppear {
                if isActive {
                    if fromAllSides {
                        burstPhaseDone = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                            fallPhaseDone = true
                        }
                    } else {
                        hasStartedFalling = true
                    }
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
    let fromAllSides: Bool
    let burstDone: Bool
    let fallDone: Bool

    private var seed: Double {
        Double(index) * 0.1
    }

    /// Which edge (0 top, 1 right, 2 bottom, 3 left)
    private var edge: Int {
        index % 4
    }

    /// Position along that edge 0...1
    private var t: CGFloat {
        CGFloat((seed * 97).truncatingRemainder(dividingBy: 1))
    }

    private var startX: CGFloat {
        CGFloat((seed * 97).truncatingRemainder(dividingBy: 1)) * width
    }

    private var endX: CGFloat {
        startX + CGFloat((seed * 31).truncatingRemainder(dividingBy: 1) - 0.5) * 180
    }

    // All-sides: start on edge (just outside)
    private var edgeStartX: CGFloat {
        switch edge {
        case 0, 2: return t * width
        case 1: return width + 24
        default: return -24
        }
    }

    private var edgeStartY: CGFloat {
        switch edge {
        case 0: return -24
        case 1, 3: return t * height
        default: return height + 24
        }
    }

    // Burst end: inward with power (quick move toward center)
    private var burstEndX: CGFloat {
        switch edge {
        case 0, 2: return t * width
        case 1: return width * 0.82
        default: return width * 0.18
        }
    }

    private var burstEndY: CGFloat {
        switch edge {
        case 0: return height * 0.12
        case 1, 3: return t * height
        default: return height * 0.88
        }
    }

    // Final: fall below with paper drift
    private var paperFallX: CGFloat {
        burstEndX + CGFloat((seed * 47).truncatingRemainder(dividingBy: 1) - 0.5) * 120
    }

    private var color: Color {
        colors[index % colors.count]
    }

    private var delay: Double {
        Double((index % 15)) * 0.06
    }

    private var burstDelay: Double {
        Double(index % 25) * 0.008
    }

    private var size: CGFloat {
        let base = CGFloat(8 + (index % 10))
        return index % 5 == 0 ? base * 1.4 : base
    }

    private var rotationDegrees: Double {
        Double(index % 360) + (fallDone ? Double((index * 7) % 180) : 0)
    }

    var body: some View {
        Group {
            if fromAllSides {
                pieceContent
                    .position(
                        x: fallPhaseX,
                        y: fallPhaseY
                    )
                    .rotationEffect(.degrees(rotationDegrees))
                    .animation(phaseAnimation, value: fallDone)
                    .animation(burstAnimation, value: burstDone)
            } else {
                pieceContent
                    .position(x: isFallen ? endX : startX, y: isFallen ? height + 80 : -30)
                    .rotationEffect(.degrees(Double(index % 360)))
                    .animation(
                        isFallen
                            ? .easeIn(duration: duration).delay(delay)
                            : .default,
                        value: isFallen
                    )
            }
        }
    }

    private var pieceContent: some View {
        RoundedRectangle(cornerRadius: index % 2 == 0 ? 3 : size / 2)
            .fill(color)
            .frame(width: size, height: index % 2 == 0 ? size * 1.5 : size)
            .shadow(color: color.opacity(0.6), radius: 1)
    }

    private var fallPhaseX: CGFloat {
        if !burstDone { return edgeStartX }
        if !fallDone { return burstEndX }
        return paperFallX
    }

    private var fallPhaseY: CGFloat {
        if !burstDone { return edgeStartY }
        if !fallDone { return burstEndY }
        return height + 80
    }

    private var burstAnimation: Animation {
        .easeOut(duration: 0.18)
        .delay(burstDelay)
    }

    private var phaseAnimation: Animation {
        .easeIn(duration: min(duration * 0.65, 2.8))
        .delay(delay * 0.7)
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
