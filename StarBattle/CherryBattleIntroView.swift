//
//  CherryBattleIntroView.swift
//  Cherry Battle — intro / welcome screen
//
//  Shows the "Cherry Battle" star-fighter key-art splash full-bleed and
//  makes it feel like a live brawl: a repeating one-two impact that shakes the frame,
//  flashes light where the fists clash, and sends a shockwave ring rippling out — over
//  a slow breathing zoom, with sparkles twinkling around the logo. Tapping anywhere
//  (or waiting a beat) drops into the game.
//
//  The artwork lives in the asset catalog as `SplashArt`. Its own comic wordmark is
//  baked into the image; the in-game title (`GameTitle`) echoes that lettering in a
//  quieter form.
//
//  No external packages required. iOS 17+ (uses KeyframeAnimator).
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct CherryBattleIntroView: View {

    /// Called when the user taps Play.
    var onPlay: () -> Void = {}

    @State private var appeared = false

    /// The animated state driven by the looping "battle" keyframes.
    private struct SplashPose {
        var zoom: CGFloat = 1.06    // breathing Ken-Burns zoom
        var shakeX: CGFloat = 0     // impact camera-shake
        var shakeY: CGFloat = 0
        var rot: Double = 0         // tiny rotational kick on impact
        var flash: CGFloat = 0      // clash flash intensity (0…1)
        var ring: CGFloat = 0       // shockwave progress (0 hidden … 1 fully expanded)
    }

    /// Where the two fists meet, as a fraction of the screen — the flash and shockwave
    /// radiate from here.
    private let clash = UnitPoint(x: 0.5, y: 0.46)

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // A deep-space gradient behind the art: dark navy at the top and bottom
                // fading to a richer blue through the middle (where the clash sits), so
                // the letterbox margins on a wide iPad read as a continuation of the
                // starfield rather than a flat slab.
                LinearGradient(
                    stops: [
                        .init(color: Color(hex: 0x0A1230), location: 0.0),
                        .init(color: Color(hex: 0x1E3370), location: 0.30),
                        .init(color: Color(hex: 0x2A47A0), location: 0.46),
                        .init(color: Color(hex: 0x172A63), location: 0.66),
                        .init(color: Color(hex: 0x0A1230), location: 1.0),
                    ],
                    startPoint: .top, endPoint: .bottom)

                KeyframeAnimator(initialValue: SplashPose(), repeating: true) { pose in
                    art(geo: geo, pose: pose)
                } keyframes: { _ in
                    // A ~2.2s loop: a beat of calm, then a snappy one-two that shakes,
                    // flashes and ripples, then settles.
                    KeyframeTrack(\.zoom) {
                        CubicKeyframe(1.13, duration: 1.1)
                        CubicKeyframe(1.06, duration: 1.1)
                    }
                    KeyframeTrack(\.flash) {
                        LinearKeyframe(0, duration: 0.45)
                        SpringKeyframe(1.0, duration: 0.13, spring: .snappy)
                        CubicKeyframe(0, duration: 0.50)
                        SpringKeyframe(0.85, duration: 0.13, spring: .snappy)
                        CubicKeyframe(0, duration: 0.99)
                    }
                    KeyframeTrack(\.shakeX) {
                        LinearKeyframe(0, duration: 0.45)
                        CubicKeyframe(9, duration: 0.05)
                        CubicKeyframe(-7, duration: 0.05)
                        CubicKeyframe(4, duration: 0.05)
                        CubicKeyframe(0, duration: 0.05)
                        LinearKeyframe(0, duration: 0.43)
                        CubicKeyframe(6, duration: 0.05)
                        CubicKeyframe(-4, duration: 0.05)
                        CubicKeyframe(0, duration: 0.05)
                        LinearKeyframe(0, duration: 0.97)
                    }
                    KeyframeTrack(\.shakeY) {
                        LinearKeyframe(0, duration: 0.45)
                        CubicKeyframe(-5, duration: 0.06)
                        CubicKeyframe(4, duration: 0.06)
                        CubicKeyframe(0, duration: 0.06)
                        LinearKeyframe(0, duration: 1.57)
                    }
                    KeyframeTrack(\.rot) {
                        LinearKeyframe(0, duration: 0.45)
                        CubicKeyframe(1.4, duration: 0.06)
                        CubicKeyframe(-1.1, duration: 0.06)
                        CubicKeyframe(0, duration: 0.06)
                        LinearKeyframe(0, duration: 1.57)
                    }
                    KeyframeTrack(\.ring) {
                        LinearKeyframe(0, duration: 0.45)
                        LinearKeyframe(1, duration: 0.55)
                        LinearKeyframe(1, duration: 1.20)
                    }
                }

                sparkleLayer(geo)

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
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .ignoresSafeArea()
        // Opaque from the first frame — the base colour and art fully cover the game
        // board beneath, so it never flashes through. Only the scale animates in.
        .scaleEffect(appeared ? 1 : 1.14)   // punchy pop-in
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) { appeared = true }
        }
    }

    /// The key-art's native aspect (width ÷ height).
    private static let artAspect: CGFloat = 1408.0 / 3040.0

    /// The rect the whole aspect-fit artwork occupies within `size`: it fills a phone
    /// almost exactly and sits centred with blank side margins on a wider iPad.
    private func artFrame(in size: CGSize) -> CGRect {
        let fitW = min(size.width, size.height * Self.artAspect)
        let fitH = fitW / Self.artAspect
        return CGRect(x: (size.width - fitW) / 2, y: (size.height - fitH) / 2,
                      width: fitW, height: fitH)
    }

    /// The artwork plus the impact effects, transformed by the current pose.
    private func art(geo: GeometryProxy, pose: SplashPose) -> some View {
        let w = geo.size.width, h = geo.size.height
        let art = artFrame(in: geo.size)
        // Where the two stars clash, mapped onto the displayed art.
        let center = CGPoint(x: art.minX + art.width * clash.x,
                             y: art.minY + art.height * clash.y)
        return ZStack {
            // The whole key-art, shown aspect-fit (never cropped), carrying the motion.
            Image("SplashArt")
                .resizable()
                .scaledToFit()
                .frame(width: w, height: h)
                .scaleEffect(pose.zoom)
                .rotationEffect(.degrees(pose.rot), anchor: .center)
                .offset(x: pose.shakeX, y: pose.shakeY)
                .frame(width: w, height: h)
                .clipped()
                .accessibilityElement()
                .accessibilityLabel("Cherry Battle")

            // Clash flash — sized to the displayed art, not the whole (wide) screen.
            RadialGradient(
                gradient: Gradient(colors: [.white.opacity(0.85),
                                            Color(hex: 0xFFC24D, alpha: 0.55), .clear]),
                center: .center, startRadius: 1, endRadius: art.width * 0.32)
                .frame(width: art.width * 0.8, height: art.width * 0.8)
                .scaleEffect(0.8 + pose.flash * 0.7)
                .opacity(0.22 + pose.flash * 0.78)
                .blendMode(.screen)
                .position(center)

            // Shockwave ring rippling out from the collision.
            Circle()
                .strokeBorder(
                    LinearGradient(colors: [.white, Color(hex: 0xFF5A5A), Color(hex: 0x4D9BFF)],
                                   startPoint: .leading, endPoint: .trailing),
                    lineWidth: max(2.5, art.width * 0.022))
                .frame(width: art.width * 0.5, height: art.width * 0.5)
                .scaleEffect(0.15 + pose.ring * 1.55)
                .opacity(pose.ring <= 0.001 ? 0 : Double(1 - pose.ring))
                .blendMode(.screen)
                .position(center)
        }
        .frame(width: w, height: h)
    }

    /// A handful of twinkling sparkles scattered around the logo, echoing the art.
    private func sparkleLayer(_ geo: GeometryProxy) -> some View {
        let art = artFrame(in: geo.size)
        return ForEach(Self.sparkles.indices, id: \.self) { i in
            let s = Self.sparkles[i]
            SparkleView(delay: s.delay, sizePt: s.size)
                .position(x: art.minX + art.width * s.x, y: art.minY + art.height * s.y)
        }
        .allowsHitTesting(false)
    }

    /// Sparkle placements as fractions of the screen (near the logo and the clash).
    private static let sparkles: [(x: CGFloat, y: CGFloat, size: CGFloat, delay: Double)] = [
        (0.16, 0.13, 34, 0.0),
        (0.85, 0.11, 26, 0.35),
        (0.30, 0.20, 20, 0.7),
        (0.72, 0.225, 22, 0.9),
        (0.50, 0.31, 18, 1.2),
        (0.12, 0.42, 16, 1.5)
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
            .scaleEffect(on ? 1 : 0.2)
            .opacity(on ? 1 : 0.1)
            .rotationEffect(.degrees(on ? 25 : -25))
            .shadow(color: .white.opacity(0.85), radius: 4)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true).delay(delay)) {
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
