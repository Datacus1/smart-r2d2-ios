import SwiftUI
import UIKit

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var ble = R2D2BLEClient()
    @State private var isConnectionPresented = false
    @State private var isDiagnosticsPresented = false

    var body: some View {
        GeometryReader { proxy in
            let isLandscape = proxy.size.width > proxy.size.height

            ZStack {
                BlueprintBackground()
                    .ignoresSafeArea()

                if isLandscape {
                    landscapeConsole
                        .padding(.horizontal, 16)
                        .padding(.bottom, 10)
                } else {
                    portraitConsole
                        .padding(.horizontal, 18)
                        .padding(.bottom, 18)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .safeAreaInset(edge: .top) {
            TopControlBar(
                state: ble.state,
                rssi: ble.lastRSSI,
                isReady: ble.isReady,
                toolsAction: { isDiagnosticsPresented = true },
                connectionAction: { isConnectionPresented = true },
                settingsAction: { isDiagnosticsPresented = true }
            )
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 8)
        }
        .onChange(of: scenePhase) { newPhase in
            guard newPhase != .active else {
                return
            }
            if ble.isReady {
                ble.stopDrive()
            }
        }
        .onDisappear {
            if ble.isReady {
                ble.stopDrive()
            }
        }
        .sheet(isPresented: $isConnectionPresented) {
            ConnectionConsole(ble: ble)
        }
        .sheet(isPresented: $isDiagnosticsPresented) {
            DiagnosticsConsole(ble: ble)
        }
    }

    private var landscapeConsole: some View {
        HStack(spacing: 14) {
            ZStack {
                R2D2BodyView(isReady: ble.isReady)

                headControlRow(width: 74, height: 64)
                    .padding(.horizontal, 54)
                    .offset(y: -108)

                DrivePad(
                    isEnabled: ble.isReady,
                    start: { ble.startDrive($0) },
                    stop: { ble.stopDrive() }
                )
                .frame(width: 222, height: 222)
                .offset(x: 8, y: 72)

                EmergencyStopButton(isEnabled: ble.isReady) {
                    ble.stopDrive()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack(spacing: 14) {
                ExpressionRail { expression in
                    ble.playExpression(expression)
                }
                .disabled(!ble.isReady)
                .opacity(ble.isReady ? 1 : 0.45)

                Spacer()
            }
            .frame(width: 126)
        }
    }

    private var portraitConsole: some View {
        VStack(spacing: 16) {
            ZStack {
                R2D2BodyView(isReady: ble.isReady)

                headControlRow(width: 76, height: 62)
                .padding(.horizontal, 38)
                .offset(y: -116)

                DrivePad(
                    isEnabled: ble.isReady,
                    start: { ble.startDrive($0) },
                    stop: { ble.stopDrive() }
                )
                .frame(width: 236, height: 236)
                .offset(y: 96)

                EmergencyStopButton(isEnabled: ble.isReady) {
                    ble.stopDrive()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 12)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            ExpressionRail { expression in
                ble.playExpression(expression)
            }
            .disabled(!ble.isReady)
            .opacity(ble.isReady ? 1 : 0.45)
        }
    }

    private func headControlRow(width: CGFloat, height: CGFloat) -> some View {
        HStack {
            HeadButton(position: .left, isEnabled: ble.isReady) {
                ble.setHead(.left)
            }
            .frame(width: width, height: height)

            Spacer()

            HeadButton(position: .right, isEnabled: ble.isReady) {
                ble.setHead(.right)
            }
            .frame(width: width, height: height)
        }
    }
}

private struct BlueprintBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.02, green: 0.08, blue: 0.18),
                    Color(red: 0.03, green: 0.17, blue: 0.32),
                    Color(red: 0.01, green: 0.07, blue: 0.16)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            GridPattern()
                .stroke(Color.cyan.opacity(0.16), lineWidth: 1)

            BlueprintArcs()
                .stroke(Color.cyan.opacity(0.18), lineWidth: 1.1)

            RadialGradient(
                colors: [Color.cyan.opacity(0.24), Color.clear],
                center: .center,
                startRadius: 20,
                endRadius: 360
            )
            .blendMode(.screen)
        }
    }
}

private enum Haptics {
    static func tap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func press() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
}

private struct GridPattern: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let minor: CGFloat = 18
        let major: CGFloat = minor * 4

        var x = rect.minX
        while x <= rect.maxX {
            path.move(to: CGPoint(x: x, y: rect.minY))
            path.addLine(to: CGPoint(x: x, y: rect.maxY))
            x += minor
        }

        var y = rect.minY
        while y <= rect.maxY {
            path.move(to: CGPoint(x: rect.minX, y: y))
            path.addLine(to: CGPoint(x: rect.maxX, y: y))
            y += minor
        }

        x = rect.minX
        while x <= rect.maxX {
            path.move(to: CGPoint(x: x, y: rect.minY))
            path.addLine(to: CGPoint(x: x, y: rect.maxY))
            x += major
        }

        y = rect.minY
        while y <= rect.maxY {
            path.move(to: CGPoint(x: rect.minX, y: y))
            path.addLine(to: CGPoint(x: rect.maxX, y: y))
            y += major
        }

        return path
    }
}

private struct BlueprintArcs: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.maxX * 0.75, y: rect.midY * 0.72)

        for radius in stride(from: rect.height * 0.32, through: rect.height * 1.05, by: rect.height * 0.14) {
            path.addArc(center: center, radius: radius, startAngle: .degrees(205), endAngle: .degrees(345), clockwise: false)
        }

        path.move(to: CGPoint(x: rect.maxX * 0.45, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX * 0.82, y: rect.maxY))
        path.move(to: CGPoint(x: rect.maxX * 0.62, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX * 0.98, y: rect.maxY * 0.88))

        return path
    }
}

private struct R2D2BodyView: View {
    let isReady: Bool

    var body: some View {
        GeometryReader { proxy in
            let width = min(proxy.size.width * 0.62, proxy.size.height * 0.88)
            let height = min(proxy.size.height * 0.98, width * 1.42)

            ZStack {
                sideLegs(width: width, height: height)
                body(width: width, height: height)
                dome(width: width, height: height)
            }
            .frame(width: width * 1.32, height: height)
            .position(x: proxy.size.width * 0.48, y: proxy.size.height * 0.53)
            .shadow(color: .black.opacity(0.45), radius: 16, x: 0, y: 8)
        }
    }

    private func sideLegs(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(LinearGradient(colors: [.white, .gray.opacity(0.75)], startPoint: .leading, endPoint: .trailing))
                .frame(width: width * 0.18, height: height * 0.58)
                .offset(x: -width * 0.54, y: height * 0.18)

            RoundedRectangle(cornerRadius: 16)
                .fill(LinearGradient(colors: [.gray.opacity(0.75), .white], startPoint: .leading, endPoint: .trailing))
                .frame(width: width * 0.18, height: height * 0.58)
                .offset(x: width * 0.54, y: height * 0.18)

            Capsule()
                .fill(Color.black.opacity(0.75))
                .frame(width: width * 0.12, height: height * 0.5)
                .offset(x: -width * 0.62, y: height * 0.2)

            Capsule()
                .fill(Color.black.opacity(0.75))
                .frame(width: width * 0.12, height: height * 0.5)
                .offset(x: width * 0.62, y: height * 0.2)
        }
    }

    private func body(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18)
                .fill(LinearGradient(colors: [Color.white, Color(red: 0.72, green: 0.77, blue: 0.82)], startPoint: .top, endPoint: .bottom))
                .overlay {
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color(red: 0.18, green: 0.33, blue: 0.55), lineWidth: 3)
                }
                .frame(width: width, height: height * 0.74)
                .offset(y: height * 0.16)

            VStack(spacing: height * 0.025) {
                HStack(spacing: width * 0.035) {
                    smallPanel(width: width * 0.18, height: height * 0.075)
                    smallPanel(width: width * 0.13, height: height * 0.075)
                    Circle()
                        .fill(isReady ? Color(red: 0.95, green: 0.1, blue: 0.08) : Color.gray)
                        .frame(width: width * 0.12)
                    Circle()
                        .fill(Color.black.opacity(0.8))
                        .frame(width: width * 0.12)
                }

                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(red: 0.05, green: 0.2, blue: 0.36).opacity(0.72))
                    .frame(width: width * 0.76, height: height * 0.43)
                    .overlay {
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.cyan.opacity(0.62), lineWidth: 2)
                    }

                HStack(spacing: width * 0.03) {
                    ForEach(0..<4, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color(red: 0.09, green: 0.17, blue: 0.34).opacity(0.85))
                            .frame(width: width * 0.14, height: height * 0.09)
                    }
                }
            }
            .offset(y: height * 0.14)
        }
    }

    private func dome(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            DomeShape()
                .fill(LinearGradient(colors: [Color.white, Color(red: 0.62, green: 0.67, blue: 0.76)], startPoint: .top, endPoint: .bottom))
                .overlay {
                    DomeShape()
                        .stroke(Color(red: 0.16, green: 0.29, blue: 0.6), lineWidth: 3)
                }
                .frame(width: width, height: height * 0.34)
                .offset(y: -height * 0.31)

            RoundedRectangle(cornerRadius: 7)
                .fill(Color(red: 0.04, green: 0.13, blue: 0.45))
                .frame(width: width * 0.28, height: height * 0.13)
                .offset(x: -width * 0.06, y: -height * 0.38)

            Circle()
                .fill(Color.black)
                .frame(width: width * 0.16)
                .overlay(Circle().fill(Color.white.opacity(0.18)).frame(width: width * 0.06).offset(x: -4, y: -5))
                .offset(x: width * 0.02, y: -height * 0.39)

            HStack(spacing: width * 0.08) {
                Rectangle()
                    .fill(Color(red: 0.04, green: 0.13, blue: 0.45))
                    .frame(width: width * 0.18, height: height * 0.07)
                Rectangle()
                    .fill(Color(red: 0.04, green: 0.13, blue: 0.45))
                    .frame(width: width * 0.13, height: height * 0.07)
                Circle()
                    .fill(Color(red: 0.96, green: 0.12, blue: 0.09))
                    .frame(width: width * 0.11)
            }
            .offset(y: -height * 0.25)
        }
    }

    private func smallPanel(width: CGFloat, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(Color(red: 0.04, green: 0.13, blue: 0.45))
            .frame(width: width, height: height)
            .overlay {
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.white.opacity(0.55), lineWidth: 1)
            }
    }
}

private struct DomeShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.maxY), control: CGPoint(x: rect.midX, y: rect.minY - rect.height * 0.18))
        path.closeSubpath()
        return path
    }
}

private struct DrivePad: View {
    let isEnabled: Bool
    let start: (R2D2Protocol.DriveDirection) -> Void
    let stop: () -> Void

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.black.opacity(0.26))
                .overlay {
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.cyan.opacity(isEnabled ? 0.28 : 0.12), lineWidth: 1)
                }
                .frame(width: 204, height: 204)
                .shadow(color: Color.cyan.opacity(isEnabled ? 0.28 : 0), radius: 10)

            RoundedRectangle(cornerRadius: 6)
                .fill(Color(red: 0.03, green: 0.16, blue: 0.28).opacity(0.78))
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.cyan.opacity(0.58), lineWidth: 2)
                }
                .rotationEffect(.degrees(45))
                .frame(width: 148, height: 148)

            XLines()
                .stroke(Color.cyan.opacity(0.34), lineWidth: 1.4)
                .padding(30)

            PadSegment(direction: .up, isEnabled: isEnabled, start: { start(.forward) }, stop: stop)
                .frame(width: 120, height: 76)
                .offset(y: -67)

            PadSegment(direction: .down, isEnabled: isEnabled, start: { start(.backward) }, stop: stop)
                .frame(width: 120, height: 76)
                .offset(y: 67)

            PadSegment(direction: .left, isEnabled: isEnabled, start: { start(.forwardLeft) }, stop: stop)
                .frame(width: 76, height: 120)
                .offset(x: -67)

            PadSegment(direction: .right, isEnabled: isEnabled, start: { start(.forwardRight) }, stop: stop)
                .frame(width: 76, height: 120)
                .offset(x: 67)

            Button {
                Haptics.tap()
                stop()
            } label: {
                Diamond()
                    .fill(Color(red: 0.04, green: 0.22, blue: 0.34).opacity(isEnabled ? 0.82 : 0.36))
                    .overlay {
                        Diamond()
                            .stroke(Color.cyan.opacity(isEnabled ? 0.85 : 0.25), lineWidth: 2)
                    }
                    .overlay {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white.opacity(isEnabled ? 0.95 : 0.35))
                    }
            }
            .buttonStyle(.plain)
            .disabled(!isEnabled)
            .frame(width: 54, height: 54)
            .accessibilityLabel("Stop movement")
        }
    }
}

private enum PadDirection {
    case up
    case down
    case left
    case right

    var symbolName: String {
        switch self {
        case .up: return "arrowtriangle.up.fill"
        case .down: return "arrowtriangle.down.fill"
        case .left: return "arrowtriangle.left.fill"
        case .right: return "arrowtriangle.right.fill"
        }
    }
}

private struct PadSegment: View {
    let direction: PadDirection
    let isEnabled: Bool
    let start: () -> Void
    let stop: () -> Void

    @State private var isPressed = false

    var body: some View {
        ZStack {
            DPadSegmentShape(direction: direction)
                .fill(segmentFill)
                .overlay {
                    DPadSegmentShape(direction: direction)
                        .stroke(Color.cyan.opacity(isEnabled ? 0.72 : 0.18), lineWidth: 2)
                }

            Image(systemName: direction.symbolName)
                .font(.system(size: 34, weight: .black))
                .foregroundStyle(.white.opacity(isEnabled ? 0.96 : 0.35))
                .shadow(color: Color.cyan.opacity(0.9), radius: isEnabled ? 7 : 0)
        }
        .contentShape(DPadSegmentShape(direction: direction))
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard isEnabled, !isPressed else {
                        return
                    }
                    isPressed = true
                    Haptics.press()
                    start()
                }
                .onEnded { _ in
                    guard isPressed else {
                        return
                    }
                    isPressed = false
                    stop()
                }
        )
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(accessibilityTitle)
    }

    private var segmentFill: LinearGradient {
        let colors = isPressed
            ? [Color.cyan.opacity(0.75), Color(red: 0.04, green: 0.42, blue: 0.62).opacity(0.9)]
            : [Color(red: 0.04, green: 0.25, blue: 0.4).opacity(isEnabled ? 0.9 : 0.35), Color(red: 0.02, green: 0.11, blue: 0.2).opacity(0.9)]

        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private var accessibilityTitle: String {
        switch direction {
        case .up: return "Move forward"
        case .down: return "Move backward"
        case .left: return "Turn left"
        case .right: return "Turn right"
        }
    }
}

private struct DPadSegmentShape: Shape {
    let direction: PadDirection

    func path(in rect: CGRect) -> Path {
        var path = Path()

        switch direction {
        case .up:
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        case .down:
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        case .left:
            path.move(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        case .right:
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        }

        path.closeSubpath()
        return path
    }
}

private struct XLines: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        return path
    }
}

private struct Diamond: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        path.closeSubpath()
        return path
    }
}

private struct HeadButton: View {
    let position: R2D2Protocol.HeadPosition
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            ZStack {
                BeveledPanel()
                    .fill(Color(red: 0.04, green: 0.31, blue: 0.5).opacity(isEnabled ? 0.96 : 0.42))
                    .overlay {
                        BeveledPanel()
                            .stroke(Color.cyan.opacity(isEnabled ? 0.92 : 0.26), lineWidth: 2)
                    }
                    .shadow(color: Color.cyan.opacity(isEnabled ? 0.42 : 0), radius: 8)

                VStack(spacing: 3) {
                    Image(systemName: position == .left ? "arrow.turn.up.left" : "arrow.turn.up.right")
                        .font(.system(size: 24, weight: .black))
                    Image(systemName: "arcade.stick.console")
                        .font(.system(size: 17, weight: .semibold))
                }
                .foregroundStyle(.white.opacity(isEnabled ? 0.94 : 0.35))
                .shadow(color: Color.cyan.opacity(0.75), radius: isEnabled ? 5 : 0)
            }
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel(position == .left ? "Rotate head left" : "Rotate head right")
    }
}

private struct ExpressionRail: View {
    let action: (R2D2Protocol.Expression) -> Void

    var body: some View {
        ZStack {
            BracketFrame()
                .stroke(Color.cyan.opacity(0.72), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

            VStack(spacing: 12) {
                ForEach(R2D2Protocol.Expression.allCases) { expression in
                    Button {
                        Haptics.tap()
                        action(expression)
                    } label: {
                        BeveledPanel()
                            .fill(Color(red: 0.04, green: 0.25, blue: 0.38).opacity(0.94))
                            .overlay {
                                BeveledPanel()
                                    .stroke(Color.cyan.opacity(0.74), lineWidth: 1.5)
                            }
                            .overlay {
                                HStack(spacing: 7) {
                                    Image(systemName: expression.symbolName)
                                        .font(.system(size: 21, weight: .bold))
                                    Text(expression.title.uppercased())
                                        .font(.system(size: 9, weight: .black))
                                        .lineLimit(1)
                                }
                                .foregroundStyle(.white)
                                .shadow(color: Color.cyan.opacity(0.85), radius: 5)
                            }
                    }
                    .buttonStyle(.plain)
                    .frame(width: 92, height: 54)
                    .accessibilityLabel(expression.title)
                }
            }
            .padding(.vertical, 18)
        }
        .frame(width: 122, height: 272)
    }
}

private struct BracketFrame: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let notch: CGFloat = 18

        path.move(to: CGPoint(x: rect.minX + notch, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + notch))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - notch))
        path.addLine(to: CGPoint(x: rect.minX + notch, y: rect.maxY))

        path.move(to: CGPoint(x: rect.maxX - notch, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + notch))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - notch))
        path.addLine(to: CGPoint(x: rect.maxX - notch, y: rect.maxY))

        return path
    }
}

private struct BeveledPanel: Shape {
    func path(in rect: CGRect) -> Path {
        let cut = min(rect.width, rect.height) * 0.22
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + cut, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - cut))
        path.addLine(to: CGPoint(x: rect.maxX - cut, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + cut))
        path.closeSubpath()
        return path
    }
}

private struct TopControlBar: View {
    let state: R2D2BLEClient.ConnectionState
    let rssi: Int?
    let isReady: Bool
    let toolsAction: () -> Void
    let connectionAction: () -> Void
    let settingsAction: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            HUDIconButton(
                systemImage: "wrench.and.screwdriver",
                accessibilityLabel: "Open BLE diagnostics",
                isEnabled: true,
                action: toolsAction
            )

            Spacer(minLength: 8)

            StatusPill(state: state, rssi: rssi, isReady: isReady, action: connectionAction)

            Spacer(minLength: 8)

            HUDIconButton(
                systemImage: "gearshape.fill",
                accessibilityLabel: "Open settings",
                isEnabled: true,
                action: settingsAction
            )
        }
        .frame(height: 56)
    }
}

private struct EmergencyStopButton: View {
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.press()
            action()
        } label: {
            HStack(spacing: 7) {
                Image(systemName: "stop.fill")
                    .font(.system(size: 13, weight: .black))
                Text("STOP")
                    .font(.system(size: 13, weight: .black))
            }
            .foregroundStyle(.white.opacity(isEnabled ? 1 : 0.38))
            .frame(width: 106, height: 44)
            .background(Color(red: 0.28, green: 0.02, blue: 0.04).opacity(isEnabled ? 0.9 : 0.42), in: RoundedRectangle(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.red.opacity(isEnabled ? 0.72 : 0.22), lineWidth: 1.5)
            }
            .shadow(color: Color.red.opacity(isEnabled ? 0.36 : 0), radius: 8)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel("Emergency stop")
    }
}

private struct HUDIconButton: View {
    let systemImage: String
    var accessibilityLabel: String? = nil
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(red: 0.02, green: 0.12, blue: 0.22).opacity(0.82))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.cyan.opacity(isEnabled ? 0.68 : 0.24), lineWidth: 1.5)
                    }
                    .shadow(color: Color.cyan.opacity(isEnabled ? 0.22 : 0), radius: 8)

                Image(systemName: systemImage)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white.opacity(isEnabled ? 0.96 : 0.38))
            }
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .frame(width: 52, height: 52)
        .accessibilityLabel(accessibilityLabel ?? systemImage)
    }
}

private struct StatusPill: View {
    let state: R2D2BLEClient.ConnectionState
    let rssi: Int?
    let isReady: Bool
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            HStack(spacing: 8) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 9, height: 9)
                    .shadow(color: statusColor.opacity(0.75), radius: 5)

                Text(title)
                    .font(.system(size: 14, weight: .black))
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)

                if let rssi, isReady {
                    Text("\(rssi)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.white.opacity(0.62))
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .frame(minWidth: 170, maxWidth: 230, minHeight: 52, maxHeight: 52)
            .background(Color(red: 0.02, green: 0.12, blue: 0.22).opacity(0.84), in: RoundedRectangle(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.cyan.opacity(0.62), lineWidth: 1.5)
            }
            .shadow(color: Color.cyan.opacity(isReady ? 0.32 : 0.16), radius: 9)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }

    private var title: String {
        switch state {
        case .ready(let name): return "CONNECTED: \(name)"
        case .scanning: return "SCANNING..."
        case .connecting(let name): return "CONNECTING: \(name)"
        case .discovering(let name): return "DISCOVERING: \(name)"
        case .poweredOff: return "BLUETOOTH OFF"
        case .failed: return "FAILED"
        case .disconnected: return "DISCONNECTED"
        default: return "CONNECT"
        }
    }

    private var statusColor: Color {
        switch state {
        case .ready: return .green
        case .failed, .poweredOff: return .red
        case .scanning, .connecting, .discovering: return .yellow
        default: return .cyan.opacity(0.55)
        }
    }
}

private struct ConnectionConsole: View {
    @ObservedObject var ble: R2D2BLEClient
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        ble.startScan()
                    } label: {
                        Label("Scan", systemImage: "antenna.radiowaves.left.and.right")
                    }
                    .disabled(ble.isScanning)

                    Button {
                        ble.connectBestMatch()
                    } label: {
                        Label("Connect", systemImage: "link")
                    }

                    Button(role: .destructive) {
                        ble.disconnect()
                    } label: {
                        Label("Disconnect", systemImage: "xmark")
                    }
                }

                if !ble.discoveredToys.isEmpty {
                    Section("Nearby") {
                        ForEach(ble.discoveredToys) { toy in
                            Button {
                                ble.connect(toy)
                                dismiss()
                            } label: {
                                HStack {
                                    Label(toy.name, systemImage: toy.advertisesControlService ? "dot.radiowaves.left.and.right" : "questionmark.circle")
                                    Spacer()
                                    Text("\(toy.rssi) dBm")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(ble.state.title)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct DiagnosticsConsole: View {
    @ObservedObject var ble: R2D2BLEClient
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Toy") {
                    Button {
                        ble.setLED(.blue)
                    } label: {
                        Label("Blue Light", systemImage: "lightbulb.fill")
                    }

                    Button {
                        ble.setLED(.red)
                    } label: {
                        Label("Red Light", systemImage: "lightbulb")
                    }

                    Button {
                        ble.setLED(.off)
                    } label: {
                        Label("Lights Off", systemImage: "lightbulb.slash")
                    }

                    Button(role: .destructive) {
                        ble.stopDrive()
                        ble.stopAudio()
                    } label: {
                        Label("Stop", systemImage: "stop.fill")
                    }

                    Button(role: .destructive) {
                        ble.powerDownToy()
                    } label: {
                        Label("Sleep", systemImage: "power")
                    }
                }

                Section("BLE") {
                    diagnosticRow("Device", value: deviceName)
                    diagnosticRow("Service", value: R2D2Protocol.serviceUUID.uuidString)
                    diagnosticRow("Write characteristic", value: R2D2Protocol.writeCharacteristicUUID.uuidString)
                    diagnosticRow("Notify 1", value: R2D2Protocol.notifyCharacteristicUUID.uuidString)
                    diagnosticRow("Notify 2", value: R2D2Protocol.radioNotifyCharacteristicUUID.uuidString)
                    diagnosticRow("Last write", value: ble.lastWriteHex.isEmpty ? "None" : ble.lastWriteHex)
                    diagnosticRow("Last notify", value: ble.lastNotificationHex.isEmpty ? "None" : ble.lastNotificationHex)
                    diagnosticRow("Connection state", value: ble.state.title)
                    diagnosticRow("RSSI", value: ble.lastRSSI.map { "\($0) dBm" } ?? "None")
                }

                Section("Log") {
                    if ble.logEntries.isEmpty {
                        Text("No events")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(ble.logEntries.prefix(20)) { entry in
                            Text(entry.message)
                                .font(.caption.monospaced())
                        }
                    }
                }
            }
            .navigationTitle("Console")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Clear") {
                        ble.clearLog()
                    }
                    .disabled(ble.logEntries.isEmpty)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var deviceName: String {
        if case .ready(let name) = ble.state {
            return name
        }
        return "2ndHeroD"
    }

    private func diagnosticRow(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.monospaced())
                .textSelection(.enabled)
        }
    }
}

#Preview {
    ContentView()
}
