//
//  CherryBattleIntroView.swift
//  Cherry Battle — intro / welcome screen
//
//  HOW TO INTEGRATE (Xcode):
//  1. Drag this file into your project (check "Copy items if needed").
//  2. Show it as your first screen, e.g. in your App:
//
//        @main
//        struct CherryBattleApp: App {
//            var body: some Scene {
//                WindowGroup {
//                    CherryBattleIntroView {
//                        // called when the user taps Play —
//                        // navigate to your puzzle/game view here
//                    }
//                }
//            }
//        }
//
//  3. Or push/navigate from it however your app is structured.
//
//  FONT: this uses the system rounded font (a close, zero-setup match for the
//  mockup's "Fredoka"). To use Fredoka exactly, add the .ttf to your target,
//  declare it in Info.plist (UIAppFonts), then replace the two
//  `.system(size:…, design: .rounded)` calls with `.custom("Fredoka", size:…)`.
//
//  No external packages required. iOS 17+ (uses Canvas / SwiftUI animations).
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct CherryBattleIntroView: View {

    /// Called when the user taps Play.
    var onPlay: () -> Void = {}

    @AppStorage(SettingsKey.pieceStyle) private var pieceRaw = PieceStyle.cherry.rawValue
    private var piece: PieceStyle { PieceStyle(rawValue: pieceRaw) ?? .cherry }

    @State private var appeared = false

    // MARK: Board data (mirrors the mockup)
    // Coloured regions, 6×6. Each number is a region id.
    private let regions: [[Int]] = [
        [1, 1, 1, 2, 2, 2],
        [1, 1, 3, 2, 2, 4],
        [1, 3, 3, 3, 4, 4],
        [5, 5, 3, 4, 4, 6],
        [5, 5, 5, 6, 6, 6],
        [5, 5, 6, 6, 6, 6]
    ]
    // Cells holding a cherry pair, keyed by (row*6 + col) → drop-in order.
    private let cherryOrder: [Int: Double] = [
        1: 0, 4: 1, 12: 2, 17: 3, 26: 4, 30: 5, 35: 6
    ]

    var body: some View {
        ZStack {
            RadialGradient(
                gradient: Gradient(stops: [
                    .init(color: Color(hex: 0x220912), location: 0.0),
                    .init(color: Color(hex: 0x140609), location: 0.58),
                    .init(color: Color(hex: 0x0B0405), location: 1.0)
                ]),
                center: UnitPoint(x: 0.5, y: 0.40),
                startRadius: 0, endRadius: 560
            )
            .ignoresSafeArea()

            // Tap anywhere to skip ahead (the intro also advances on its own).
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    #if canImport(UIKit)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    #endif
                    onPlay()
                }

            VStack(spacing: 0) {
                board
                    .padding(.bottom, 42)

                wordmark
            }
        }
        .onAppear { appeared = true }
    }

    /// The glyph that drops onto the intro board — the player's chosen piece, keeping
    /// the custom cherry-pair art when it's the cherry.
    @ViewBuilder private var introPiece: some View {
        if piece == .cherry {
            CherryPair(width: 34)
        } else {
            PieceView(style: piece, isWrong: false, size: 40)
        }
    }

    // MARK: Board
    private var board: some View {
        VStack(spacing: 0) {
            ForEach(0..<6, id: \.self) { r in
                HStack(spacing: 0) {
                    ForEach(0..<6, id: \.self) { c in
                        let idx = r * 6 + c
                        ZStack {
                            Rectangle().fill(regionColor(regions[r][c]))
                            if let order = cherryOrder[idx] {
                                introPiece
                                    .scaleEffect(appeared ? 1 : 0.4)
                                    .offset(y: appeared ? 0 : -24)
                                    .opacity(appeared ? 1 : 0)
                                    .animation(
                                        .spring(response: 0.5, dampingFraction: 0.62)
                                            .delay(0.35 + order * 0.15),
                                        value: appeared
                                    )
                            }
                        }
                        .frame(width: 44, height: 44)
                        .overlay(Rectangle().stroke(Color.white.opacity(0.07), lineWidth: 1))
                    }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(11)
        .background(RoundedRectangle(cornerRadius: 20).fill(Color.white.opacity(0.03)))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.09), lineWidth: 1))
        .shadow(color: Color(hex: 0xE51937, alpha: 0.30), radius: 30)
        .scaleEffect(appeared ? 1 : 0.9)
        .opacity(appeared ? 1 : 0)
        .animation(.easeOut(duration: 0.7), value: appeared)
    }

    // MARK: Wordmark
    private var wordmark: some View {
        VStack(spacing: 14) {
            (Text("Cherry ").foregroundColor(Color(hex: 0xFFF3F4))
             + Text("Battle").foregroundColor(Color(hex: 0xE51937)))
                .font(.system(size: 44, weight: .bold, design: .rounded))

            Text("THE FUN LOGIC PUZZLE")
                .font(.system(size: 11.5, weight: .medium))
                .tracking(3)
                .foregroundColor(Color(hex: 0xFFF3F4, alpha: 0.5))
        }
        .offset(y: appeared ? 0 : 20)
        .opacity(appeared ? 1 : 0)
        .animation(.easeOut(duration: 0.9).delay(0.35), value: appeared)
    }

    private func regionColor(_ id: Int) -> Color {
        switch id {
        case 1: return Color(hex: 0xE51937, alpha: 0.18) // cherry
        case 2: return Color(hex: 0xF59E0B, alpha: 0.18) // amber
        case 3: return Color(hex: 0x3DA35D, alpha: 0.18) // green
        case 4: return Color(hex: 0x6366F1, alpha: 0.18) // indigo
        case 5: return Color(hex: 0xEC4899, alpha: 0.18) // pink
        default: return Color(hex: 0x22D3EE, alpha: 0.16) // cyan
        }
    }
}

// MARK: - Cherry pair piece

struct CherryPair: View {
    var width: CGFloat = 34
    private let green = Color(hex: 0x3DA35D)
    private let red = Color(hex: 0xE51937)

    var body: some View {
        Canvas { ctx, size in
            let s = size.width / 40.0
            func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * s, y: y * s) }

            var leftStem = Path()
            leftStem.move(to: p(20, 9))
            leftStem.addCurve(to: p(12, 28), control1: p(16, 18), control2: p(14, 22))
            ctx.stroke(leftStem, with: .color(green),
                       style: StrokeStyle(lineWidth: 2.4 * s, lineCap: .round))

            var rightStem = Path()
            rightStem.move(to: p(20, 9))
            rightStem.addCurve(to: p(28, 28), control1: p(24, 18), control2: p(26, 22))
            ctx.stroke(rightStem, with: .color(green),
                       style: StrokeStyle(lineWidth: 2.4 * s, lineCap: .round))

            var leaf = Path()
            leaf.move(to: p(20, 8))
            leaf.addCurve(to: p(34, 6), control1: p(24, 3), control2: p(31, 2))
            leaf.addCurve(to: p(20, 8), control1: p(30, 11), control2: p(23, 11))
            leaf.closeSubpath()
            ctx.fill(leaf, with: .color(green))

            ctx.fill(Path(ellipseIn: CGRect(x: (12 - 8) * s, y: (33 - 8) * s, width: 16 * s, height: 16 * s)),
                     with: .color(red))
            ctx.fill(Path(ellipseIn: CGRect(x: (28 - 8) * s, y: (33 - 8) * s, width: 16 * s, height: 16 * s)),
                     with: .color(red))

            ctx.fill(Path(ellipseIn: CGRect(x: (9 - 2.4) * s, y: (30 - 1.8) * s, width: 4.8 * s, height: 3.6 * s)),
                     with: .color(.white.opacity(0.45)))
            ctx.fill(Path(ellipseIn: CGRect(x: (25 - 2.4) * s, y: (30 - 1.8) * s, width: 4.8 * s, height: 3.6 * s)),
                     with: .color(.white.opacity(0.45)))
        }
        .frame(width: width, height: width * 44.0 / 40.0)
    }
}

// MARK: - Helpers

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xff) / 255.0,
                  green: Double((hex >> 8) & 0xff) / 255.0,
                  blue: Double(hex & 0xff) / 255.0,
                  opacity: alpha)
    }
}

#Preview {
    CherryBattleIntroView()
}
