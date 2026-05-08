import SwiftUI

struct ContentView: View {
    @StateObject private var ble = R2D2BLEClient()
    @State private var isConnectionPresented = false
    @State private var isDiagnosticsPresented = false

    var body: some View {
        GeometryReader { proxy in
            let isLandscape = proxy.size.width > proxy.size.height

            ZStack {
                BlueprintBackground()

                if isLandscape {
                    landscapeConsole
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                } else {
                    portraitConsole
                        .padding(.horizontal, 18)
                        .padding(.vertical, 14)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .ignoresSafeArea()
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

                VStack {
                    HStack {
                        HUDIconButton(systemImage: "chevron.left", isEnabled: true) {
                            isConnectionPresented = true
                        }

                        Spacer()

                        HeadButton(position: .left, isEnabled: ble.isReady) {
                            ble.setHead(.left)
                        }
                        .frame(width: 72, height: 62)
                        .offset(x: -6, y: 26)

                        HeadButton(position: .right, isEnabled: ble.isReady) {
                            ble.setHead(.right)
                        }
                        .frame(width: 72, height: 62)
                        .offset(x: 8, y: 26)
                    }

                    Spacer()
                }

                DrivePad(
                    isEnabled: ble.isReady,
                    start: { ble.startDrive($0) },
                    stop: { ble.stopDrive() }
                )
                .frame(width: 222, height: 222)
                .offset(x: 8, y: 72)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack(spacing: 14) {
                StatusPill(state: ble.state, rssi: ble.lastRSSI, isReady: ble.isReady) {
                    isConnectionPresented = true
                }

                Spacer()

                ExpressionRail { expression in
                    ble.playExpression(expression)
                }
                .disabled(!ble.isReady)
                .opacity(ble.isReady ? 1 : 0.45)

                Spacer()

                HUDIconButton(systemImage: "questionmark", isEnabled: true) {
                    isDiagnosticsPresented = true
                }
            }
            .frame(width: 126)
        }
    }

    private var portraitConsole: some View {
        VStack(spacing: 16) {
            HStack {
                HUDIconButton(systemImage: "chevron.left", isEnabled: true) {
                    isConnectionPresented = true
                }

                Spacer()

                StatusPill(state: ble.state, rssi: ble.lastRSSI, isReady: ble.isReady) {
                    isConnectionPresented = true
                }

                Spacer()

                HUDIconButton(systemImage: "questionmark", isEnabled: true) {
                    isDiagnosticsPresented = true
                }
            }

            ZStack {
                R2D2BodyView(isReady: ble.isReady)

                HStack {
                    HeadButton(position: .left, isEnabled: ble.isReady) {
                        ble.setHead(.left)
                    }
                    .frame(width: 76, height: 62)

                    Spacer()

                    HeadButton(position: .right, isEnabled: ble.isReady) {
                        ble.setHead(.right)
                    }
                    .frame(width: 76, height: 62)
                }
                .padding(.horizontal, 38)
                .offset(y: -116)

                DrivePad(
                    isEnabled: ble.isReady,
                    start: { ble.startDrive($0) },
                    stop: { ble.stopDrive() }
                )
                .frame(width: 236, height: 236)
                .offset(y: 96)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            ExpressionRail { expression in
                ble.playExpression(expression)
            }
            .disabled(!ble.isReady)
            .opacity(ble.isReady ? 1 : 0.45)
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
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(red: 0.03, green: 0.16, blue: 0.28).opacity(0.72))
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.cyan.opacity(0.58), lineWidth: 2)
                }
                .rotationEffect(.degrees(45))
                .frame(width: 148, height: 148)

            XLines()
                .stroke(Color.cyan.opacity(0.7), lineWidth: 2)
                .padding(18)

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

            Button(action: stop) {
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
    }

    private var segmentFill: LinearGradient {
        let colors = isPressed
            ? [Color.cyan.opacity(0.75), Color(red: 0.04, green: 0.42, blue: 0.62).opacity(0.9)]
            : [Color(red: 0.04, green: 0.25, blue: 0.4).opacity(isEnabled ? 0.9 : 0.35), Color(red: 0.02, green: 0.11, blue: 0.2).opacity(0.9)]

        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
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
        Button(action: action) {
            ZStack {
                BeveledPanel()
                    .fill(Color(red: 0.04, green: 0.27, blue: 0.42).opacity(isEnabled ? 0.92 : 0.38))
                    .overlay {
                        BeveledPanel()
                            .stroke(Color.cyan.opacity(isEnabled ? 0.78 : 0.22), lineWidth: 2)
                    }

                VStack(spacing: 3) {
                    Image(systemName: position == .left ? "arrow.turn.up.left" : "arrow.turn.up.right")
                        .font(.system(size: 22, weight: .black))
                    Image(systemName: "arcade.stick.console")
                        .font(.system(size: 17, weight: .semibold))
                }
                .foregroundStyle(.white.opacity(isEnabled ? 0.94 : 0.35))
                .shadow(color: Color.cyan.opacity(0.75), radius: isEnabled ? 5 : 0)
            }
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
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
                        action(expression)
                    } label: {
                        BeveledPanel()
                            .fill(Color(red: 0.04, green: 0.24, blue: 0.36).opacity(0.9))
                            .overlay {
                                BeveledPanel()
                                    .stroke(Color.cyan.opacity(0.62), lineWidth: 1.5)
                            }
                            .overlay {
                                Image(systemName: expression.symbolName)
                                    .font(.system(size: 25, weight: .bold))
                                    .foregroundStyle(.white)
                                    .shadow(color: Color.cyan.opacity(0.8), radius: 5)
                            }
                    }
                    .buttonStyle(.plain)
                    .frame(width: 74, height: 54)
                }
            }
            .padding(.vertical, 18)
        }
        .frame(width: 108, height: 272)
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

private struct HUDIconButton: View {
    let systemImage: String
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(red: 0.02, green: 0.12, blue: 0.22).opacity(0.7))
                    .overlay {
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.cyan.opacity(0.6), lineWidth: 1.5)
                    }

                Image(systemName: systemImage)
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(.white.opacity(isEnabled ? 0.96 : 0.38))
            }
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .frame(width: 48, height: 40)
    }
}

private struct StatusPill: View {
    let state: R2D2BLEClient.ConnectionState
    let rssi: Int?
    let isReady: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Circle()
                    .fill(isReady ? Color.green : Color.cyan.opacity(0.35))
                    .frame(width: 9, height: 9)

                Text(shortTitle)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                if let rssi, isReady {
                    Text("\(rssi)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.white.opacity(0.62))
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: 126)
            .background(Color(red: 0.02, green: 0.12, blue: 0.22).opacity(0.72), in: RoundedRectangle(cornerRadius: 6))
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.cyan.opacity(0.55), lineWidth: 1.5)
            }
        }
        .buttonStyle(.plain)
    }

    private var shortTitle: String {
        if isReady {
            return "R2-D2"
        }

        switch state {
        case .scanning: return "SCAN"
        case .connecting, .discovering: return "LINK"
        case .poweredOff: return "BT OFF"
        case .failed: return "ERROR"
        default: return "CONNECT"
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
}

#Preview {
    ContentView()
}
