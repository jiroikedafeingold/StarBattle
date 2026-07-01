//
//  CherryBattleIntroView.swift
//  Cherry Battle — intro / welcome screen
//
//  Shows the "Cherry Battle" key-art splash (two cherries squaring off) full-bleed,
//  brought to life with gentle motion: a slow breathing zoom, a throbbing energy
//  flash where the fists clash, and a few twinkling sparkles. Tapping anywhere (or
//  waiting a beat) drops into the game.
//
//  The artwork lives in the asset catalog as `SplashArt`. Its own comic wordmark is
//  baked into the image; the in-game title (`GameTitle`) echoes that lettering in a
//  quieter form.
//
//  No external packages required. iOS 17+.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct CherryBattleIntroView: View {

    /// Called when the user taps Play.
    var onPlay: () -> Void = {}

    @State private var appeared = false
    /// Slow, always-on breathing zoom of the artwork.
    @State private var breathe = false
    /// Faster pulse driving the clash flash and sparkle twinkle.
    @State private var pulse = false

    var body: some View {
        ZStack {
            // Deep blue base matching the art's border, in case of any letterbox.
            Color(hex: 0x12275C).ignoresSafeArea()

            // The key art, filling the screen with a slow Ken-Burns breath. The mild
            // over-scale also crops the artwork's mocked-up status bar off the top.
            Image("SplashArt")
                .resizable()
                .scaledToFill()
                .scaleEffect(breathe ? 1.11 : 1.06)
                .ignoresSafeArea()
                .accessibilityLabel("Cherry Battle")

            clashFlash
            sparkleLayer

            // Tap anywhere to skip ahead (the intro also advances on its own).
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    #if canImport(UIKit)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    #endif
                    onPlay()
                }
        }
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) { appeared = true }
            withAnimation(.easeInOut(duration: 5).repeatForever(autoreverses: true)) { breathe = true }
            withAnimation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true)) { pulse = true }
        }
    }

    /// A throbbing burst of light where the two cherries' fists meet — makes the clash
    /// in the art feel like it's crackling with energy.
    private var clashFlash: some View {
        GeometryReader { geo in
            RadialGradient(
                gradient: Gradient(colors: [
                    .white.opacity(0.75),
                    Color(hex: 0xFFC24D, alpha: 0.5),
                    .clear
                ]),
                center: .center, startRadius: 1, endRadius: geo.size.width * 0.3)
                .frame(width: geo.size.width * 0.7, height: geo.size.width * 0.7)
                .scaleEffect(pulse ? 1.12 : 0.9)
                .opacity(pulse ? 0.85 : 0.4)
                .blendMode(.screen)
                .position(x: geo.size.width * 0.5, y: geo.size.height * 0.46)
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }

    /// A handful of twinkling sparkles scattered around the logo, echoing the art.
    private var sparkleLayer: some View {
        GeometryReader { geo in
            ForEach(Self.sparkles.indices, id: \.self) { i in
                let s = Self.sparkles[i]
                SparkleView(delay: s.delay, sizePt: s.size)
                    .position(x: geo.size.width * s.x, y: geo.size.height * s.y)
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }

    /// Sparkle placements as fractions of the screen (near the logo and the clash).
    private static let sparkles: [(x: CGFloat, y: CGFloat, size: CGFloat, delay: Double)] = [
        (0.17, 0.135, 26, 0.0),
        (0.83, 0.115, 20, 0.5),
        (0.31, 0.205, 15, 1.1),
        (0.71, 0.225, 17, 0.8),
        (0.50, 0.30, 13, 1.4)
    ]
}

// MARK: - Sparkle

/// A four-point sparkle that twinkles (scales and fades) and drifts in rotation on a
/// loop, each starting after its own delay so they don't blink in unison.
private struct SparkleView: View {
    var delay: Double
    var sizePt: CGFloat
    @State private var on = false

    var body: some View {
        SparkleShape()
            .fill(.white)
            .frame(width: sizePt, height: sizePt)
            .scaleEffect(on ? 1 : 0.3)
            .opacity(on ? 0.9 : 0.15)
            .rotationEffect(.degrees(on ? 18 : -18))
            .shadow(color: .white.opacity(0.7), radius: 3)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true).delay(delay)) {
                    on = true
                }
            }
    }
}

/// A four-point sparkle/twinkle: concave sides pinching in between the points.
private struct SparkleShape: Shape {
    func path(in r: CGRect) -> Path {
        let c = CGPoint(x: r.midX, y: r.midY)
        let outer = min(r.width, r.height) / 2
        let inner = outer * 0.18   // deep pinch → thin, pointed arms
        var p = Path()
        for i in 0..<4 {
            let tip = Double(i) * .pi / 2 - .pi / 2
            let mid = tip + .pi / 4
            let tipPt = CGPoint(x: c.x + outer * CoreGraphics.cos(tip),
                                y: c.y + outer * CoreGraphics.sin(tip))
            let midPt = CGPoint(x: c.x + inner * CoreGraphics.cos(mid),
                                y: c.y + inner * CoreGraphics.sin(mid))
            if i == 0 { p.move(to: tipPt) } else { p.addLine(to: tipPt) }
            p.addLine(to: midPt)
        }
        p.closeSubpath()
        return p
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
