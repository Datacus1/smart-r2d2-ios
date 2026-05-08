import SwiftUI

struct ContentView: View {
    @StateObject private var ble = R2D2BLEClient()
    @State private var driveEnabled = false
    @State private var selectedLight: R2D2Protocol.LEDColor = .off

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    statusPanel
                    connectionPanel
                    headPanel
                    drivePanel
                    lightsPanel
                    soundPanel
                    utilityPanel
                    logPanel
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Smart R2-D2")
        }
    }

    private var statusPanel: some View {
        Panel {
            HStack(spacing: 12) {
                Circle()
                    .fill(ble.isReady ? Color.green : (ble.isScanning ? Color.cyan : Color.secondary))
                    .frame(width: 12, height: 12)

                VStack(alignment: .leading, spacing: 2) {
                    Text(ble.state.title)
                        .font(.headline)
                    if let rssi = ble.lastRSSI {
                        Text("\(rssi) dBm")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Toggle("Auto", isOn: $ble.autoConnect)
                    .labelsHidden()
            }
        }
    }

    private var connectionPanel: some View {
        Panel(title: "Connection") {
            HStack(spacing: 10) {
                Button {
                    ble.startScan()
                } label: {
                    Label("Scan", systemImage: "antenna.radiowaves.left.and.right")
                }
                .buttonStyle(.borderedProminent)
                .disabled(ble.isScanning)

                Button {
                    ble.connectBestMatch()
                } label: {
                    Label("Connect", systemImage: "link")
                }
                .buttonStyle(.bordered)

                Button(role: .destructive) {
                    ble.disconnect()
                } label: {
                    Label("Disconnect", systemImage: "xmark")
                }
                .buttonStyle(.bordered)
            }

            if !ble.discoveredToys.isEmpty {
                VStack(spacing: 8) {
                    ForEach(ble.discoveredToys) { toy in
                        Button {
                            ble.connect(toy)
                        } label: {
                            HStack {
                                Image(systemName: toy.advertisesControlService ? "dot.radiowaves.left.and.right" : "questionmark.circle")
                                VStack(alignment: .leading) {
                                    Text(toy.name)
                                        .font(.subheadline.weight(.semibold))
                                    Text("\(toy.rssi) dBm")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.secondary)
                            }
                            .padding(8)
                            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var headPanel: some View {
        Panel(title: "Head") {
            HStack(spacing: 10) {
                ForEach(R2D2Protocol.HeadPosition.allCases) { position in
                    ControlButton(title: position.title, systemImage: position.symbolName, isEnabled: ble.isReady) {
                        ble.setHead(position)
                    }
                }
            }
        }
    }

    private var drivePanel: some View {
        Panel(title: "Drive") {
            Toggle("Enable", isOn: $driveEnabled)
                .toggleStyle(.switch)

            HStack(spacing: 12) {
                MomentaryCommandButton(
                    title: "Forward",
                    systemImage: "arrow.up",
                    isEnabled: ble.isReady && driveEnabled,
                    start: { ble.startDrive(.forward) },
                    stop: { ble.stopDrive() }
                )

                ControlButton(title: "Stop", systemImage: "stop.fill", isEnabled: ble.isReady) {
                    ble.stopDrive()
                }
                .tint(.red)

                MomentaryCommandButton(
                    title: "Back",
                    systemImage: "arrow.down",
                    isEnabled: ble.isReady && driveEnabled,
                    start: { ble.startDrive(.backward) },
                    stop: { ble.stopDrive() }
                )
            }
        }
    }

    private var lightsPanel: some View {
        Panel(title: "Lights") {
            Picker("Color", selection: $selectedLight) {
                ForEach(R2D2Protocol.LEDColor.allCases) { color in
                    Text(color.rawValue).tag(color)
                }
            }
            .pickerStyle(.segmented)
            .disabled(!ble.isReady)
            .onChange(of: selectedLight) { newValue in
                ble.setLED(newValue)
            }
        }
    }

    private var soundPanel: some View {
        Panel(title: "Sound") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 10)], spacing: 10) {
                ForEach(R2D2Protocol.Sound.allCases) { sound in
                    ControlButton(title: sound.title, systemImage: "speaker.wave.2.fill", isEnabled: ble.isReady) {
                        ble.playSound(sound)
                    }
                }

                ControlButton(title: "Stop", systemImage: "speaker.slash.fill", isEnabled: ble.isReady) {
                    ble.stopAudio()
                }
                .tint(.red)
            }
        }
    }

    private var utilityPanel: some View {
        Panel(title: "Toy") {
            HStack(spacing: 10) {
                ControlButton(title: "Sleep", systemImage: "power", isEnabled: ble.isReady) {
                    ble.powerDownToy()
                }
                .tint(.orange)

                ControlButton(title: "Clear", systemImage: "trash", isEnabled: !ble.logEntries.isEmpty) {
                    ble.clearLog()
                }
            }
        }
    }

    private var logPanel: some View {
        Panel(title: "Log") {
            if ble.logEntries.isEmpty {
                Text("No events")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(ble.logEntries.prefix(16)) { entry in
                        Text(entry.message)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }
}

private struct Panel<Content: View>: View {
    var title: String?
    @ViewBuilder let content: Content

    init(title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title = title {
                Text(title)
                    .font(.headline)
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct ControlButton: View {
    let title: String
    let systemImage: String
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .disabled(!isEnabled)
    }
}

private struct MomentaryCommandButton: View {
    let title: String
    let systemImage: String
    let isEnabled: Bool
    let start: () -> Void
    let stop: () -> Void

    @State private var isPressed = false

    var body: some View {
        Label(title, systemImage: systemImage)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(isPressed ? Color.accentColor.opacity(0.25) : Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.accentColor.opacity(isEnabled ? 0.35 : 0.0), lineWidth: 1)
            }
            .foregroundStyle(isEnabled ? Color.primary : Color.secondary)
            .contentShape(Rectangle())
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
}

#Preview {
    ContentView()
}
