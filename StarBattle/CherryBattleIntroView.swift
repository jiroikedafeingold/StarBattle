//
//  CherryBattleIntroView.swift
//  Cherry Battle — intro / welcome screen
//
//  Shows the app's mascot: a plump cherry that riffs on the app icon, but with a
//  face and boxing gloves — bobbing on its feet and throwing jabs, "ready for a
//  fight." Below it sits the wordmark. Tapping anywhere (or waiting a beat) drops
//  into the game.
//
//  FONT: uses the system rounded font (a close, zero-setup match for the mockup's
//  "Fredoka"). To use Fredoka exactly, add the .ttf, declare it in Info.plist
//  (UIAppFonts), then swap the `.system(…, design: .rounded)` calls for
//  `.custom("Fredoka", size:…)`.
//
//  No external packages required. iOS 17+ (uses KeyframeAnimator / SwiftUI shapes).
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct CherryBattleIntroView: View {

    /// Called when the user taps Play.
    var onPlay: () -> Void = {}

    @State private var appeared = false

    var body: some View {
        ZStack {
            RadialGradient(
                gradient: Gradient(stops: [
                    .init(color: Color(hex: 0x220912), location: 0.0),
                    .init(color: Color(hex: 0x140609), location: 0.58),
                    .init(color: Color(hex: 0x0B0405), location: 1.0)
                ]),
                center: UnitPoint(x: 0.5, y: 0.42),
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

            VStack(spacing: 30) {
                FighterCherryView(size: 190)

                wordmark
            }
            .padding(.bottom, 16)
        }
        .onAppear { appeared = true }
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
}

// MARK: - Fighter cherry mascot

/// A cherry with a determined face and two boxing gloves, bobbing on its feet and
/// throwing a quick one-two jab on a loop. Drawn entirely from SwiftUI shapes so it
/// scales cleanly and keeps the icon's palette (cherry red, glossy highlight, green
/// leaf). Pops in with a spring on appear.
struct FighterCherryView: View {

    /// Overall width; the character lays out proportionally to this.
    var size: CGFloat = 190

    @State private var appeared = false

    // Palette (matches the icon / in-game cherry).
    private let cherryRed = Color(hex: 0xE51937)
    private let green = Color(hex: 0x3DA35D)

    /// The animated pose driven by the looping keyframes.
    private struct FighterPose {
        var bobY: CGFloat = 0    // vertical bounce
        var jab: CGFloat = 0     // 0 = guard, 1 = glove fully extended
        var lean: Double = 0     // body lean into the punch, degrees
        var spark: CGFloat = 0   // impact starburst (0…1)
    }

    private var bodyD: CGFloat { size * 0.60 }
    private var gloveD: CGFloat { size * 0.32 }

    var body: some View {
        KeyframeAnimator(initialValue: FighterPose(), repeating: true) { pose in
            content(pose)
        } keyframes: { _ in
            // A ~2.6s loop: settle and bob, then a snappy one-two jab, then reset.
            KeyframeTrack(\.bobY) {
                CubicKeyframe(-size * 0.035, duration: 0.6)
                CubicKeyframe(0, duration: 0.6)
                CubicKeyframe(-size * 0.02, duration: 0.5)
                CubicKeyframe(0, duration: 0.9)
            }
            KeyframeTrack(\.jab) {
                LinearKeyframe(0, duration: 1.15)
                SpringKeyframe(1, duration: 0.22, spring: .snappy)
                SpringKeyframe(0, duration: 0.33)
                SpringKeyframe(1, duration: 0.20, spring: .snappy)
                SpringKeyframe(0, duration: 0.30)
                LinearKeyframe(0, duration: 0.40)
            }
            KeyframeTrack(\.lean) {
                LinearKeyframe(0, duration: 1.15)
                CubicKeyframe(9, duration: 0.22)
                CubicKeyframe(0, duration: 0.33)
                CubicKeyframe(9, duration: 0.20)
                CubicKeyframe(0, duration: 0.30)
                LinearKeyframe(0, duration: 0.40)
            }
            KeyframeTrack(\.spark) {
                LinearKeyframe(0, duration: 1.30)
                LinearKeyframe(1, duration: 0.05)
                LinearKeyframe(0, duration: 0.30)
                LinearKeyframe(1, duration: 0.05)
                LinearKeyframe(0, duration: 0.30)
                LinearKeyframe(0, duration: 0.60)
            }
        }
        .scaleEffect(appeared ? 1 : 0.5)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.62)) { appeared = true }
        }
    }

    // MARK: Composition

    private func content(_ pose: FighterPose) -> some View {
        ZStack {
            // Soft arena spotlight behind the mascot.
            Circle()
                .fill(RadialGradient(
                    gradient: Gradient(colors: [Color(hex: 0xE51937, alpha: 0.32), .clear]),
                    center: .center, startRadius: 2, endRadius: size * 0.72))
                .frame(width: size * 1.6, height: size * 1.6)
                .blur(radius: 12)

            // Ground shadow — shrinks as the cherry hops up.
            Ellipse()
                .fill(Color.black.opacity(0.30))
                .frame(width: size * 0.46, height: size * 0.10)
                .scaleEffect(1 + pose.bobY * 0.018)
                .blur(radius: 3)
                .offset(y: size * 0.53)

            character(pose)
                .rotationEffect(.degrees(pose.lean), anchor: .bottom)
                .offset(y: pose.bobY)
        }
        .frame(width: size, height: size * 1.15)
    }

    /// The cherry itself: stem/leaf, glossy body, face, and the two gloves.
    private func character(_ pose: FighterPose) -> some View {
        ZStack {
            stemLeaf
            bodyView
            faceView

            // Guard glove (character's right hand), held up by the cheek.
            glove(flip: false)
                .rotationEffect(.degrees(14))
                .offset(x: -size * 0.29, y: size * 0.01)

            // Jabbing glove: rests in guard, then thrusts up-and-out.
            glove(flip: true)
                .rotationEffect(.degrees(-8 - pose.jab * 12))
                .scaleEffect(1 + pose.jab * 0.15)
                .offset(x: size * 0.29 + pose.jab * size * 0.18,
                        y: size * 0.05 - pose.jab * size * 0.34)

            // Impact starburst at the punch's peak.
            burst
                .frame(width: size * 0.34, height: size * 0.34)
                .scaleEffect(0.4 + pose.spark * 0.9)
                .opacity(pose.spark)
                .offset(x: size * 0.52, y: -size * 0.33)
        }
    }

    // MARK: Parts

    private var stemLeaf: some View {
        ZStack {
            Capsule()
                .fill(green)
                .frame(width: size * 0.035, height: size * 0.16)
                .rotationEffect(.degrees(10))
                .offset(x: size * 0.015, y: -size * 0.375)

            LeafShape()
                .fill(green)
                .frame(width: size * 0.20, height: size * 0.11)
                .overlay(
                    LeafShape().stroke(Color(hex: 0x2C7A45), lineWidth: 1)
                        .frame(width: size * 0.20, height: size * 0.11)
                )
                .rotationEffect(.degrees(-26))
                .offset(x: size * 0.13, y: -size * 0.44)
        }
    }

    private var bodyView: some View {
        Circle()
            .fill(RadialGradient(
                gradient: Gradient(colors: [Color(hex: 0xFF5A74), cherryRed, Color(hex: 0x9E0F24)]),
                center: UnitPoint(x: 0.36, y: 0.30),
                startRadius: size * 0.02, endRadius: size * 0.34))
            .frame(width: bodyD, height: bodyD)
            .overlay(
                Ellipse()
                    .fill(.white.opacity(0.5))
                    .frame(width: bodyD * 0.28, height: bodyD * 0.16)
                    .rotationEffect(.degrees(-28))
                    .offset(x: -bodyD * 0.16, y: -bodyD * 0.20)
                    .blur(radius: 1.5)
            )
            .overlay(Circle().stroke(Color(hex: 0x7A0C1C, alpha: 0.35), lineWidth: bodyD * 0.02))
    }

    private var faceView: some View {
        ZStack {
            eye.offset(x: -size * 0.115, y: -size * 0.04)
            eye.offset(x: size * 0.115, y: -size * 0.04)

            brow
                .rotationEffect(.degrees(20))
                .offset(x: -size * 0.115, y: -size * 0.135)
            brow
                .rotationEffect(.degrees(-20))
                .offset(x: size * 0.115, y: -size * 0.135)

            GrinShape()
                .fill(Color(hex: 0x5A0A16))
                .frame(width: size * 0.17, height: size * 0.075)
                .offset(y: size * 0.085)
        }
    }

    private var eye: some View {
        ZStack {
            Ellipse().fill(.white)
                .frame(width: size * 0.125, height: size * 0.155)
            Circle().fill(Color(hex: 0x201014))
                .frame(width: size * 0.072, height: size * 0.072)
                .offset(x: size * 0.012, y: size * 0.022)   // focused, downward glare
            Circle().fill(.white)
                .frame(width: size * 0.022, height: size * 0.022)
                .offset(x: size * 0.03, y: size * 0.008)
        }
    }

    private var brow: some View {
        RoundedRectangle(cornerRadius: size * 0.02)
            .fill(Color(hex: 0x3A1218))
            .frame(width: size * 0.15, height: size * 0.04)
    }

    /// A little boxing glove. `flip` mirrors the thumb so a pair can face inward.
    private func glove(flip: Bool) -> some View {
        ZStack {
            // Wrist band peeking out below the glove.
            RoundedRectangle(cornerRadius: gloveD * 0.16)
                .fill(Color.white)
                .frame(width: gloveD * 0.62, height: gloveD * 0.30)
                .offset(y: gloveD * 0.48)

            // Main padded glove.
            Circle()
                .fill(RadialGradient(
                    gradient: Gradient(colors: [Color(hex: 0xFF5A74), cherryRed, Color(hex: 0xB2122B)]),
                    center: UnitPoint(x: 0.35, y: 0.30),
                    startRadius: 1, endRadius: gloveD * 0.7))
                .frame(width: gloveD, height: gloveD)
                .overlay(Circle().stroke(Color(hex: 0x7A0C1C, alpha: 0.6), lineWidth: gloveD * 0.035))

            // Thumb.
            Circle()
                .fill(cherryRed)
                .frame(width: gloveD * 0.44, height: gloveD * 0.44)
                .overlay(Circle().stroke(Color(hex: 0x7A0C1C, alpha: 0.6), lineWidth: gloveD * 0.03))
                .offset(x: gloveD * 0.30 * (flip ? -1 : 1), y: gloveD * 0.14)

            // Seam + gloss.
            Capsule()
                .fill(Color(hex: 0x7A0C1C, alpha: 0.45))
                .frame(width: gloveD * 0.05, height: gloveD * 0.46)
            Ellipse()
                .fill(.white.opacity(0.45))
                .frame(width: gloveD * 0.26, height: gloveD * 0.15)
                .offset(x: -gloveD * 0.15, y: -gloveD * 0.18)
        }
        .frame(width: gloveD, height: gloveD)
    }

    private var burst: some View {
        ZStack {
            BurstShape().fill(Color(hex: 0xFFD23F))
            BurstShape().fill(.white).scaleEffect(0.5)
        }
    }
}

// MARK: - Shapes

/// A pointed oval leaf.
private struct LeafShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.midY))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.midY), control: CGPoint(x: r.midX, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.minX, y: r.midY), control: CGPoint(x: r.midX, y: r.maxY))
        p.closeSubpath()
        return p
    }
}

/// A confident open grin (flat top, curved bottom).
private struct GrinShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.minX, y: r.minY),
                       control: CGPoint(x: r.midX, y: r.maxY * 2))
        p.closeSubpath()
        return p
    }
}

/// A comic-book impact starburst.
private struct BurstShape: Shape {
    var points = 10
    func path(in r: CGRect) -> Path {
        var p = Path()
        let c = CGPoint(x: r.midX, y: r.midY)
        let outer = min(r.width, r.height) / 2
        let inner = outer * 0.45
        for i in 0..<(points * 2) {
            let radius = i.isMultiple(of: 2) ? outer : inner
            let a = Double(i) * .pi / Double(points) - .pi / 2
            let pt = CGPoint(x: c.x + radius * CoreGraphics.cos(a),
                             y: c.y + radius * CoreGraphics.sin(a))
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
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

#Preview("Fighter") {
    FighterCherryView(size: 220)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: 0x140609))
}
