import Combine
import CoreBluetooth
import Foundation

struct DiscoveredToy: Identifiable, Equatable {
    let id: UUID
    let peripheral: CBPeripheral
    let name: String
    let rssi: Int
    let lastSeen: Date
    let advertisesControlService: Bool

    static func == (lhs: DiscoveredToy, rhs: DiscoveredToy) -> Bool {
        lhs.id == rhs.id
    }
}

struct BLELogEntry: Identifiable {
    let id = UUID()
    let date = Date()
    let message: String
}

final class R2D2BLEClient: NSObject, ObservableObject {
    enum ConnectionState: Equatable {
        case unknown
        case unsupported
        case poweredOff
        case idle
        case scanning
        case connecting(String)
        case discovering(String)
        case ready(String)
        case disconnected
        case failed(String)

        var title: String {
            switch self {
            case .unknown: return "Checking Bluetooth"
            case .unsupported: return "Bluetooth Unsupported"
            case .poweredOff: return "Bluetooth Off"
            case .idle: return "Idle"
            case .scanning: return "Scanning"
            case .connecting(let name): return "Connecting to \(name)"
            case .discovering(let name): return "Discovering \(name)"
            case .ready(let name): return "Connected to \(name)"
            case .disconnected: return "Disconnected"
            case .failed(let reason): return reason
            }
        }
    }

    @Published private(set) var state: ConnectionState = .unknown
    @Published private(set) var discoveredToys: [DiscoveredToy] = []
    @Published private(set) var logEntries: [BLELogEntry] = []
    @Published private(set) var lastRSSI: Int?
    @Published private(set) var lastWriteHex: String = ""
    @Published private(set) var lastNotificationHex: String = ""
    @Published private(set) var lastCommandSummary: String = "Idle"
    @Published private(set) var activeDriveSummary: String?
    @Published var autoConnect = true

    private var central: CBCentralManager!
    private var targetPeripheral: CBPeripheral?
    private var notifyCharacteristic: CBCharacteristic?
    private var writeCharacteristic: CBCharacteristic?
    private var radioNotifyCharacteristic: CBCharacteristic?
    private var radioWriteCharacteristic: CBCharacteristic?
    private var keepAliveTimer: Timer?
    private var driveTimer: Timer?
    private var activeDriveDirection: R2D2Protocol.DriveDirection?
    private var routineWorkItems: [DispatchWorkItem] = []
    private var activeRoutineName: String?
    private var wantsConnectionWhenFound = false

    var isReady: Bool {
        if case .ready = state {
            return writeCharacteristic != nil
        }
        return false
    }

    var isScanning: Bool {
        if case .scanning = state {
            return true
        }
        return false
    }

    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: .main)
    }

    func startScan(connectWhenFound: Bool = false) {
        wantsConnectionWhenFound = connectWhenFound

        guard central.state == .poweredOn else {
            log("Bluetooth is not powered on")
            return
        }

        discoveredToys.removeAll()
        state = .scanning
        log("Scanning for \(R2D2Protocol.serviceUUID.uuidString)")

        central.scanForPeripherals(
            withServices: [R2D2Protocol.serviceUUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
    }

    func stopScan() {
        central.stopScan()
        wantsConnectionWhenFound = false
        if case .scanning = state {
            state = .idle
        }
        log("Scan stopped")
    }

    func connect(_ toy: DiscoveredToy) {
        central.stopScan()
        wantsConnectionWhenFound = false
        resetCharacteristics()
        targetPeripheral = toy.peripheral
        targetPeripheral?.delegate = self
        state = .connecting(toy.name)
        log("Connecting to \(toy.name)")
        central.connect(toy.peripheral, options: nil)
    }

    func connectBestMatch() {
        if let best = discoveredToys.first(where: { $0.advertisesControlService || R2D2Protocol.advertisedNames.contains($0.name) }) ?? discoveredToys.first {
            connect(best)
        } else {
            startScan(connectWhenFound: true)
        }
    }

    func disconnect() {
        wantsConnectionWhenFound = false
        cancelRoutine()
        if isReady {
            stopDrive()
        } else {
            stopDriveTimer()
        }
        stopKeepAlive()
        sendRaw(R2D2Protocol.endAppMode)

        if let targetPeripheral = targetPeripheral {
            central.cancelPeripheralConnection(targetPeripheral)
        } else {
            state = .disconnected
        }
    }

    func powerDownAndDisconnect() {
        wantsConnectionWhenFound = false
        central.stopScan()
        cancelRoutine()

        if isReady {
            stopDrive()
            lastCommandSummary = "Power down"
            sendRaw(R2D2Protocol.keepAlive)
            sendRaw(R2D2Protocol.powerDown)
        } else {
            stopDriveTimer()
        }

        stopKeepAlive()

        if let targetPeripheral {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                self?.central.cancelPeripheralConnection(targetPeripheral)
            }
        } else {
            state = .disconnected
            resetCharacteristics()
            log("Disconnected")
        }
    }

    func setHead(_ position: R2D2Protocol.HeadPosition) {
        cancelRoutine(stopMotors: true)
        lastCommandSummary = "Head \(position.title)"
        sendCommand(R2D2Protocol.head(position))
    }

    func setLED(_ color: R2D2Protocol.LEDColor) {
        cancelRoutine(stopMotors: true)
        lastCommandSummary = "\(color.rawValue) light"
        sendCommand(R2D2Protocol.led(color))
    }

    func startDrive(_ direction: R2D2Protocol.DriveDirection) {
        cancelRoutine()
        activeDriveDirection = direction
        activeDriveSummary = direction.title
        lastCommandSummary = "Drive \(direction.title)"
        sendCommand(R2D2Protocol.drive(direction))

        driveTimer?.invalidate()
        driveTimer = Timer.scheduledTimer(withTimeInterval: 0.65, repeats: true) { [weak self] _ in
            guard let self, self.activeDriveDirection == direction else {
                return
            }
            self.sendCommand(R2D2Protocol.drive(direction))
        }
    }

    func stopDrive() {
        lastCommandSummary = "Motors stopped"
        cancelRoutine()
        stopDriveTimer()
        sendCommand(R2D2Protocol.stopDrive)
    }

    func playSound(_ sound: R2D2Protocol.Sound) {
        cancelRoutine(stopMotors: true)
        lastCommandSummary = "Sound \(sound.title)"
        sendCommand(R2D2Protocol.playPlaylist(sound.rawValue))
    }

    func playPlaylist(_ playlistID: UInt16) {
        cancelRoutine(stopMotors: true)
        lastCommandSummary = "Sound \(playlistID)"
        sendCommand(R2D2Protocol.playPlaylist(playlistID))
    }

    func playExpression(_ expression: R2D2Protocol.Expression) {
        cancelRoutine(stopMotors: true)
        lastCommandSummary = expression.title
        sendCommand(R2D2Protocol.expression(expression))
    }

    func playSequence(_ sequenceID: UInt16) {
        cancelRoutine(stopMotors: true)
        lastCommandSummary = "Sequence \(sequenceID)"
        sendCommand(R2D2Protocol.highLevelSequence(sequenceID))
    }

    func playDanceSongRoutine() {
        guard isReady else {
            lastCommandSummary = "Connect first"
            log("Connect before starting dance song")
            return
        }

        cancelRoutine(stopMotors: true)
        stopDriveTimer()

        activeRoutineName = "Cantina Dance"
        activeDriveSummary = "Cantina Dance"
        lastCommandSummary = "Cantina Dance"
        sendCommand(R2D2Protocol.playPlaylist(165))
        sendCommand(R2D2Protocol.led(.blue))
        sendCommand(R2D2Protocol.head(.center))

        func queue(_ delay: TimeInterval, _ action: @escaping (R2D2BLEClient) -> Void) {
            queueRoutineCommand(after: delay, action)
        }

        func driveBurst(_ delay: TimeInterval, _ direction: R2D2Protocol.DriveDirection, duration: TimeInterval = 0.62) {
            queue(delay) { client in
                client.sendCommand(R2D2Protocol.drive(direction))
            }
            queue(delay + duration) { client in
                client.sendCommand(R2D2Protocol.stopDrive)
            }
        }

        func headAt(_ delay: TimeInterval, _ position: R2D2Protocol.HeadPosition) {
            queue(delay) { client in
                client.sendCommand(R2D2Protocol.head(position))
            }
        }

        func lightAt(_ delay: TimeInterval, _ color: R2D2Protocol.LEDColor) {
            queue(delay) { client in
                client.sendCommand(R2D2Protocol.led(color))
            }
        }

        // APK-style choreography: shuffle forward/back, turn accents, head sweeps, and light changes.
        headAt(0.4, .left)
        lightAt(0.55, .blue)
        driveBurst(0.75, .forwardLeft)
        headAt(1.25, .right)
        lightAt(1.45, .red)
        driveBurst(1.65, .backwardRight)

        headAt(2.55, .center)
        lightAt(2.75, .blue)
        driveBurst(2.95, .forwardRight)
        headAt(3.45, .left)
        driveBurst(3.85, .backwardLeft)

        lightAt(4.8, .red)
        headAt(5.0, .right)
        driveBurst(5.25, .forward)
        headAt(5.9, .center)
        driveBurst(6.25, .backward)

        lightAt(7.15, .blue)
        headAt(7.35, .left)
        driveBurst(7.6, .forwardLeft)
        headAt(8.1, .right)
        driveBurst(8.55, .backwardRight)

        lightAt(9.45, .red)
        driveBurst(9.65, .forwardRight)
        headAt(10.15, .left)
        driveBurst(10.6, .backwardLeft)

        lightAt(11.5, .blue)
        headAt(11.7, .center)
        driveBurst(12.0, .forward, duration: 0.5)
        driveBurst(12.8, .backward, duration: 0.5)
        headAt(13.45, .right)
        driveBurst(13.7, .forwardLeft)
        headAt(14.25, .left)
        driveBurst(14.65, .backwardRight)

        lightAt(15.55, .red)
        headAt(15.75, .right)
        driveBurst(16.0, .forwardRight, duration: 0.5)
        lightAt(16.45, .blue)
        headAt(16.65, .left)
        driveBurst(16.9, .backwardLeft, duration: 0.5)

        queue(17.65) { client in
            client.sendCommand(R2D2Protocol.stopDrive)
            client.sendCommand(R2D2Protocol.head(.center))
            client.sendCommand(R2D2Protocol.led(.blue))
            client.activeRoutineName = nil
            client.activeDriveSummary = nil
            client.routineWorkItems.removeAll()
            client.lastCommandSummary = "Cantina Dance done"
        }
    }

    func stopAudio() {
        cancelRoutine(stopMotors: true)
        lastCommandSummary = "Audio stopped"
        sendCommand(R2D2Protocol.stopSequences(flags: R2D2Protocol.StopFlags.audioPlaylist))
    }

    func stopSequences(flags: UInt8) {
        cancelRoutine(stopMotors: true)
        lastCommandSummary = "Stop \(String(format: "%02X", flags))"
        sendCommand(R2D2Protocol.stopSequences(flags: flags))
    }

    func clearLog() {
        logEntries.removeAll()
    }

    private func resetCharacteristics() {
        notifyCharacteristic = nil
        writeCharacteristic = nil
        radioNotifyCharacteristic = nil
        radioWriteCharacteristic = nil
    }

    private func sendRaw(_ data: Data, useRadio: Bool = false) {
        guard let peripheral = targetPeripheral else {
            log("No connected toy for TX \(data.hexString)")
            return
        }

        let characteristic = useRadio ? radioWriteCharacteristic : writeCharacteristic
        guard let characteristic else {
            log("Write characteristic not ready for TX \(data.hexString)")
            return
        }

        peripheral.writeValue(data, for: characteristic, type: .withoutResponse)
        lastWriteHex = data.hexString
        log("TX \(data.hexString)")
    }

    private func sendCommand(_ data: Data) {
        sendRaw(R2D2Protocol.keepAlive)
        sendRaw(data)
    }

    private func queueRoutineCommand(after delay: TimeInterval, _ action: @escaping (R2D2BLEClient) -> Void) {
        let item = DispatchWorkItem { [weak self] in
            guard let self, self.isReady, self.activeRoutineName != nil else {
                return
            }
            action(self)
        }
        routineWorkItems.append(item)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }

    private func cancelRoutine(stopMotors: Bool = false) {
        let hadRoutine = activeRoutineName != nil || !routineWorkItems.isEmpty
        routineWorkItems.forEach { $0.cancel() }
        routineWorkItems.removeAll()
        activeRoutineName = nil

        if hadRoutine {
            activeDriveSummary = nil
        }

        if stopMotors && isReady {
            sendCommand(R2D2Protocol.stopDrive)
        }
    }

    private func startKeepAlive() {
        stopKeepAlive()
        sendRaw(R2D2Protocol.keepAlive)
        keepAliveTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.sendRaw(R2D2Protocol.keepAlive)
        }
    }

    private func stopKeepAlive() {
        keepAliveTimer?.invalidate()
        keepAliveTimer = nil
    }

    private func stopDriveTimer() {
        activeDriveDirection = nil
        activeDriveSummary = nil
        driveTimer?.invalidate()
        driveTimer = nil
    }

    private func markReadyIfPossible() {
        guard let targetPeripheral = targetPeripheral, writeCharacteristic != nil, notifyCharacteristic != nil else {
            return
        }

        guard !isReady else {
            return
        }

        let name = targetPeripheral.name ?? "Smart R2-D2"
        state = .ready(name)
        log("Ready")
        startKeepAlive()
    }

    private func log(_ message: String) {
        let entry = BLELogEntry(message: message)
        logEntries.insert(entry, at: 0)
        if logEntries.count > 80 {
            logEntries.removeLast(logEntries.count - 80)
        }
    }
}

extension R2D2BLEClient: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            state = .idle
            log("Bluetooth powered on")
        case .poweredOff:
            stopDriveTimer()
            state = .poweredOff
            log("Bluetooth powered off")
        case .unsupported:
            stopDriveTimer()
            state = .unsupported
            log("Bluetooth unsupported")
        case .unauthorized:
            stopDriveTimer()
            state = .failed("Bluetooth Unauthorized")
            log("Bluetooth permission denied")
        case .resetting:
            stopDriveTimer()
            state = .unknown
            log("Bluetooth resetting")
        case .unknown:
            state = .unknown
        @unknown default:
            state = .unknown
        }
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        let localName = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        let name = localName ?? peripheral.name ?? "Unnamed"
        let serviceUUIDs = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] ?? []
        let advertisesControlService = serviceUUIDs.contains(R2D2Protocol.serviceUUID)
        let toy = DiscoveredToy(
            id: peripheral.identifier,
            peripheral: peripheral,
            name: name,
            rssi: RSSI.intValue,
            lastSeen: Date(),
            advertisesControlService: advertisesControlService
        )

        if let index = discoveredToys.firstIndex(where: { $0.id == toy.id }) {
            discoveredToys[index] = toy
        } else {
            discoveredToys.append(toy)
            log("Found \(name) RSSI \(RSSI.intValue)")
        }

        lastRSSI = RSSI.intValue

        if targetPeripheral == nil && (wantsConnectionWhenFound || (autoConnect && advertisesControlService)) {
            connect(toy)
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        let name = peripheral.name ?? "Smart R2-D2"
        state = .discovering(name)
        log("Connected; discovering services")
        peripheral.delegate = self
        peripheral.discoverServices([R2D2Protocol.serviceUUID])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        stopKeepAlive()
        state = .failed("Connect Failed")
        log("Connect failed: \(error?.localizedDescription ?? "unknown error")")
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        stopDriveTimer()
        stopKeepAlive()
        resetCharacteristics()
        targetPeripheral = nil
        state = .disconnected
        log("Disconnected\(error.map { ": \($0.localizedDescription)" } ?? "")")
    }
}

extension R2D2BLEClient: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            state = .failed("Service Discovery Failed")
            log("Service discovery failed: \(error.localizedDescription)")
            return
        }

        guard let services = peripheral.services, !services.isEmpty else {
            state = .failed("No R2-D2 Service")
            log("No control service found")
            return
        }

        for service in services where service.uuid == R2D2Protocol.serviceUUID {
            peripheral.discoverCharacteristics(
                [
                    R2D2Protocol.notifyCharacteristicUUID,
                    R2D2Protocol.writeCharacteristicUUID,
                    R2D2Protocol.radioNotifyCharacteristicUUID,
                    R2D2Protocol.radioWriteCharacteristicUUID
                ],
                for: service
            )
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            state = .failed("Characteristic Discovery Failed")
            log("Characteristic discovery failed: \(error.localizedDescription)")
            return
        }

        for characteristic in service.characteristics ?? [] {
            switch characteristic.uuid {
            case R2D2Protocol.notifyCharacteristicUUID:
                notifyCharacteristic = characteristic
                peripheral.setNotifyValue(true, for: characteristic)
                log("Subscribed main notify")
            case R2D2Protocol.writeCharacteristicUUID:
                writeCharacteristic = characteristic
                log("Found main write")
            case R2D2Protocol.radioNotifyCharacteristicUUID:
                radioNotifyCharacteristic = characteristic
                peripheral.setNotifyValue(true, for: characteristic)
                log("Subscribed radio notify")
            case R2D2Protocol.radioWriteCharacteristicUUID:
                radioWriteCharacteristic = characteristic
                log("Found radio write")
            default:
                break
            }
        }

        markReadyIfPossible()
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            log("RX error: \(error.localizedDescription)")
            return
        }

        guard let data = characteristic.value else {
            return
        }

        lastNotificationHex = data.hexString
        let channel = characteristic.uuid == R2D2Protocol.radioNotifyCharacteristicUUID ? "Radio RX" : "RX"
        log("\(channel) \(data.hexString)")
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            log("Notify update failed: \(error.localizedDescription)")
            return
        }

        log("Notify \(characteristic.uuid.uuidString): \(characteristic.isNotifying ? "on" : "off")")
        markReadyIfPossible()
    }
}
