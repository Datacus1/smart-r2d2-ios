import SwiftUI
import UIKit

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var ble = R2D2BLEClient()
    @State private var isConnectionPresented = false
    @State private var isDiagnosticsPresented = false
    @State private var activeCommandPanel: CommandPanel?

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
        .sheet(item: $activeCommandPanel) { panel in
            CommandPanelSheet(panel: panel, ble: ble)
        }
    }

    private var landscapeConsole: some View {
        HStack(spacing: 12) {
            R2D2Stage {
                R2D2BodyView(isReady: ble.isReady)
            }
            .frame(width: 244)

            MainControlPanel(
                isReady: ble.isReady,
                setHead: { ble.setHead($0) },
                startDrive: { ble.startDrive($0) },
                stopDrive: { ble.stopDrive() },
                setLED: { ble.setLED($0) }
            )
            .frame(width: 286)

            CommandDock(axis: .vertical) { panel in
                activeCommandPanel = panel
            }
            .frame(width: 230)
            .frame(maxHeight: .infinity, alignment: .center)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var portraitConsole: some View {
        VStack(spacing: 12) {
            R2D2Stage {
                R2D2BodyView(isReady: ble.isReady)
            }
            .frame(height: 270)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            MainControlPanel(
                isReady: ble.isReady,
                setHead: { ble.setHead($0) },
                startDrive: { ble.startDrive($0) },
                stopDrive: { ble.stopDrive() },
                setLED: { ble.setLED($0) }
            )

            CommandDock(axis: .horizontal) { panel in
                activeCommandPanel = panel
            }
        }
    }
}

private struct R2D2Stage<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.black.opacity(0.18))
                .overlay {
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.cyan.opacity(0.22), lineWidth: 1)
                }

            content
                .padding(6)
        }
    }
}

private struct MainControlPanel: View {
    let isReady: Bool
    let setHead: (R2D2Protocol.HeadPosition) -> Void
    let startDrive: (R2D2Protocol.DriveDirection) -> Void
    let stopDrive: () -> Void
    let setLED: (R2D2Protocol.LEDColor) -> Void

    var body: some View {
        VStack(spacing: 9) {
            ControlSection(title: "Head") {
                HStack(spacing: 8) {
                    ForEach(R2D2Protocol.HeadPosition.allCases) { position in
                        HeadButton(position: position, isEnabled: isReady) {
                            setHead(position)
                        }
                        .frame(maxWidth: .infinity, minHeight: 44, maxHeight: 44)
                    }
                }
            }
            .frame(height: 64)

            ControlSection(title: "Drive") {
                DrivePad(
                    isEnabled: isReady,
                    start: startDrive,
                    stop: stopDrive
                )
                .frame(width: 210, height: 142)
            }
            .frame(height: 168)

            LightDock(isEnabled: isReady, action: setLED)
                .frame(height: 56)
        }
    }
}

private struct ControlSection<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 8, weight: .black))
                .foregroundStyle(.cyan.opacity(0.78))
                .padding(.horizontal, 4)

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(6)
        .background(Color.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.cyan.opacity(0.26), lineWidth: 1)
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

private enum CommandPanel: String, CaseIterable, Identifiable {
    case head
    case shuffle
    case lights
    case sounds
    case expressions
    case dances
    case utility
    case advanced

    var id: String { rawValue }

    var title: String {
        switch self {
        case .head: return "Head"
        case .shuffle: return "Shuffle"
        case .lights: return "Lights"
        case .sounds: return "Sounds"
        case .expressions: return "Moods"
        case .dances: return "Dance"
        case .utility: return "Utility"
        case .advanced: return "Catalog"
        }
    }

    var symbolName: String {
        switch self {
        case .head: return "arrow.triangle.2.circlepath"
        case .shuffle: return "figure.walk.motion"
        case .lights: return "lightbulb.fill"
        case .sounds: return "speaker.wave.2.fill"
        case .expressions: return "face.smiling"
        case .dances: return "music.note"
        case .utility: return "viewfinder"
        case .advanced: return "number"
        }
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
                .frame(width: 210, height: 142)
                .shadow(color: Color.cyan.opacity(isEnabled ? 0.28 : 0), radius: 10)

            VStack(spacing: 4) {
                DriveControlButton(direction: .forward, isEnabled: isEnabled, start: start, stop: stop)
                    .frame(width: 70, height: 44)

                HStack(spacing: 8) {
                    DriveControlButton(direction: .forwardLeft, isEnabled: isEnabled, start: start, stop: stop)
                        .frame(width: 56, height: 46)

                    Diamond()
                        .fill(Color(red: 0.04, green: 0.22, blue: 0.34).opacity(isEnabled ? 0.72 : 0.28))
                        .overlay {
                            Diamond()
                                .stroke(Color.cyan.opacity(isEnabled ? 0.72 : 0.22), lineWidth: 2)
                        }
                        .overlay {
                            Circle()
                                .fill(Color.white.opacity(isEnabled ? 0.88 : 0.28))
                                .frame(width: 10, height: 10)
                        }
                        .frame(width: 42, height: 42)

                    DriveControlButton(direction: .forwardRight, isEnabled: isEnabled, start: start, stop: stop)
                        .frame(width: 56, height: 46)
                }

                HStack(spacing: 8) {
                    DriveControlButton(direction: .backwardLeft, isEnabled: isEnabled, start: start, stop: stop)
                        .frame(width: 56, height: 44)

                    DriveControlButton(direction: .backward, isEnabled: isEnabled, start: start, stop: stop)
                        .frame(width: 62, height: 44)

                    DriveControlButton(direction: .backwardRight, isEnabled: isEnabled, start: start, stop: stop)
                        .frame(width: 56, height: 44)
                }
            }
        }
    }
}

private struct DriveControlButton: View {
    let direction: R2D2Protocol.DriveDirection
    let isEnabled: Bool
    let start: (R2D2Protocol.DriveDirection) -> Void
    let stop: () -> Void

    @State private var isPressed = false

    var body: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(fill)
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.cyan.opacity(isEnabled ? 0.72 : 0.18), lineWidth: 1.5)
            }
            .overlay {
                Image(systemName: direction.symbolName)
                    .font(.system(size: 23, weight: .black))
                    .foregroundStyle(.white.opacity(isEnabled ? 0.96 : 0.35))
                    .shadow(color: Color.cyan.opacity(0.9), radius: isEnabled ? 6 : 0)
            }
            .contentShape(RoundedRectangle(cornerRadius: 14))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard isEnabled, !isPressed else {
                            return
                        }
                        isPressed = true
                        Haptics.press()
                        start(direction)
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
            .accessibilityLabel(direction.title)
    }

    private var fill: LinearGradient {
        let colors = isPressed
            ? [Color.cyan.opacity(0.75), Color(red: 0.04, green: 0.42, blue: 0.62).opacity(0.9)]
            : [Color(red: 0.04, green: 0.25, blue: 0.4).opacity(isEnabled ? 0.9 : 0.35), Color(red: 0.02, green: 0.11, blue: 0.2).opacity(0.9)]

        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
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
                    Image(systemName: position.symbolName)
                        .font(.system(size: 24, weight: .black))
                    Text(position.title.uppercased())
                        .font(.system(size: 8, weight: .black))
                        .lineLimit(1)
                }
                .foregroundStyle(.white.opacity(isEnabled ? 0.94 : 0.35))
                .shadow(color: Color.cyan.opacity(0.75), radius: isEnabled ? 5 : 0)
            }
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel("Move head \(position.title.lowercased())")
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

private struct CommandDock: View {
    let axis: Axis.Set
    let action: (CommandPanel) -> Void

    private let columns = [
        GridItem(.fixed(106), spacing: 8),
        GridItem(.fixed(106), spacing: 8)
    ]

    var body: some View {
        if axis == .vertical {
            ScrollView(.vertical, showsIndicators: false) {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(CommandPanel.allCases) { panel in
                        panelButton(panel, width: 106)
                    }
                }
                .padding(.vertical, 4)
            }
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(CommandPanel.allCases) { panel in
                        panelButton(panel, width: 86)
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }

    private func panelButton(_ panel: CommandPanel, width: CGFloat) -> some View {
        Button {
            Haptics.tap()
            action(panel)
        } label: {
            BeveledPanel()
                .fill(Color(red: 0.04, green: 0.25, blue: 0.38).opacity(0.94))
                .overlay {
                    BeveledPanel()
                        .stroke(Color.cyan.opacity(0.74), lineWidth: 1.5)
                }
                .overlay {
                    VStack(spacing: 4) {
                        Image(systemName: panel.symbolName)
                            .font(.system(size: 19, weight: .bold))
                        Text(panel.title.uppercased())
                            .font(.system(size: 8, weight: .black))
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    }
                    .foregroundStyle(.white)
                    .shadow(color: Color.cyan.opacity(0.85), radius: 5)
                }
        }
        .buttonStyle(.plain)
        .frame(width: width, height: 54)
        .accessibilityLabel(panel.title)
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

private struct LightDock: View {
    let isEnabled: Bool
    let action: (R2D2Protocol.LEDColor) -> Void

    var body: some View {
        HStack(spacing: 8) {
            ForEach([R2D2Protocol.LEDColor.blue, .red, .off]) { color in
                Button {
                    Haptics.tap()
                    action(color)
                } label: {
                    VStack(spacing: 3) {
                        Circle()
                            .fill(lightColor(for: color).opacity(isEnabled ? 1 : 0.3))
                            .frame(width: 11, height: 11)
                            .overlay {
                                Circle()
                                    .stroke(Color.white.opacity(color == .off ? 0.72 : 0.18), lineWidth: 1)
                            }
                            .shadow(color: lightColor(for: color).opacity(isEnabled ? 0.75 : 0), radius: 5)

                        Text(color.rawValue.uppercased())
                            .font(.system(size: 9, weight: .black))
                            .lineLimit(1)
                    }
                    .foregroundStyle(.white.opacity(isEnabled ? 0.96 : 0.35))
                    .frame(width: 54, height: 44)
                    .background(Color(red: 0.02, green: 0.13, blue: 0.22).opacity(0.86), in: RoundedRectangle(cornerRadius: 14))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.cyan.opacity(isEnabled ? 0.62 : 0.2), lineWidth: 1.3)
                    }
                }
                .buttonStyle(.plain)
                .disabled(!isEnabled)
                .accessibilityLabel("\(color.rawValue) light")
            }
        }
        .padding(5)
        .background(Color.black.opacity(0.24), in: RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.cyan.opacity(isEnabled ? 0.3 : 0.12), lineWidth: 1)
        }
    }

    private func lightColor(for color: R2D2Protocol.LEDColor) -> Color {
        switch color {
        case .blue: return .cyan
        case .red: return .red
        case .off: return Color.white.opacity(0.18)
        }
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

private struct CommandPanelSheet: View {
    let panel: CommandPanel
    @ObservedObject var ble: R2D2BLEClient
    @Environment(\.dismiss) private var dismiss
    @State private var soundSearch = ""
    @State private var rawSequenceID = 0
    @State private var rawPlaylistID = 0

    var body: some View {
        NavigationStack {
            List {
                content
            }
            .navigationTitle(panel.title)
            .searchable(text: $soundSearch, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search sounds or IDs")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch panel {
        case .head:
            Section("Direct") {
                ForEach(R2D2Protocol.HeadPosition.allCases) { position in
                    commandRow(title: position.title, systemImage: position.symbolName, detail: R2D2Protocol.head(position).hexString) {
                        ble.setHead(position)
                    }
                }
            }

            Section("Animations") {
                ForEach(R2D2Protocol.headAnimationActions) { option in
                    sequenceRow(option)
                }
            }

        case .shuffle:
            Section("Shuffle") {
                ForEach(R2D2Protocol.shuffleActions) { option in
                    sequenceRow(option)
                }
            }

        case .lights:
            Section("Direct") {
                ForEach([R2D2Protocol.LEDColor.blue, .red, .off]) { color in
                    commandRow(title: "\(color.rawValue) Light", systemImage: color == .off ? "lightbulb.slash.fill" : "lightbulb.fill", detail: R2D2Protocol.led(color).hexString) {
                        ble.setLED(color)
                    }
                }
            }

            Section("Animations") {
                ForEach(R2D2Protocol.lightSequenceActions) { option in
                    sequenceRow(option)
                }
            }

        case .sounds:
            Section("Sounds") {
                ForEach(filteredSounds) { sound in
                    commandRow(title: sound.title, systemImage: sound.symbolName, detail: "ID \(sound.playlistID)") {
                        ble.playPlaylist(sound.playlistID)
                    }
                }
            }

        case .expressions:
            Section("Mood Pools") {
                ForEach(R2D2Protocol.expressionGroups) { group in
                    groupRow(group)
                }
            }

        case .dances:
            Section("Dances and Ambient") {
                ForEach(R2D2Protocol.danceAndAmbientGroups) { group in
                    groupRow(group)
                }
            }

        case .utility:
            Section("Actions") {
                ForEach(R2D2Protocol.utilityActions) { option in
                    sequenceRow(option)
                }
            }

            Section("Stop") {
                ForEach(R2D2Protocol.stopOptions) { option in
                    stopRow(option)
                }
            }

        case .advanced:
            Section("High-Level Sequence") {
                Stepper("Sequence ID \(rawSequenceID)", value: $rawSequenceID, in: 0...477)
                commandRow(title: "Play Sequence", systemImage: "play.fill", detail: R2D2Protocol.highLevelSequence(UInt16(rawSequenceID)).hexString) {
                    ble.playSequence(UInt16(rawSequenceID))
                }
            }

            Section("Playlist Sound") {
                Stepper("Playlist ID \(rawPlaylistID)", value: $rawPlaylistID, in: 0...174)
                commandRow(title: "Play Sound", systemImage: "speaker.wave.2.fill", detail: R2D2Protocol.playPlaylist(UInt16(rawPlaylistID)).hexString) {
                    ble.playPlaylist(UInt16(rawPlaylistID))
                }
            }

            Section("Stop") {
                ForEach(R2D2Protocol.stopOptions) { option in
                    stopRow(option)
                }
            }
        }
    }

    private var filteredSounds: [R2D2Protocol.PlaylistOption] {
        let query = soundSearch.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return R2D2Protocol.soundOptions
        }

        return R2D2Protocol.soundOptions.filter { option in
            option.title.localizedCaseInsensitiveContains(query) || "\(option.playlistID)".contains(query)
        }
    }

    private func sequenceRow(_ option: R2D2Protocol.SequenceOption) -> some View {
        commandRow(title: option.title, systemImage: option.symbolName, detail: "ID \(option.sequenceID)") {
            ble.playSequence(option.sequenceID)
        }
    }

    private func groupRow(_ group: R2D2Protocol.SequenceGroup) -> some View {
        commandRow(title: group.title, systemImage: group.symbolName, detail: "\(group.ids.count) variants") {
            guard let sequenceID = group.ids.randomElement() else {
                return
            }
            ble.playSequence(sequenceID)
        }
    }

    private func stopRow(_ option: R2D2Protocol.StopOption) -> some View {
        commandRow(title: option.title, systemImage: option.symbolName, detail: R2D2Protocol.stopSequences(flags: option.flags).hexString) {
            ble.stopSequences(flags: option.flags)
        }
    }

    private func commandRow(title: String, systemImage: String, detail: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 19, weight: .semibold))
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                    Text(detail)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
        }
        .disabled(!ble.isReady)
        .accessibilityLabel(title)
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
