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

    func setHead(_ position: R2D2Protocol.HeadPosition) {
        sendCommand(R2D2Protocol.head(position))
    }

    func setLED(_ color: R2D2Protocol.LEDColor) {
        sendCommand(R2D2Protocol.led(color))
    }

    func startDrive(_ direction: R2D2Protocol.DriveDirection) {
        activeDriveDirection = direction
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
        stopDriveTimer()
        sendCommand(R2D2Protocol.stopDrive)
    }

    func playSound(_ sound: R2D2Protocol.Sound) {
        sendCommand(R2D2Protocol.playPlaylist(sound.rawValue))
    }

    func playPlaylist(_ playlistID: UInt16) {
        sendCommand(R2D2Protocol.playPlaylist(playlistID))
    }

    func playExpression(_ expression: R2D2Protocol.Expression) {
        sendCommand(R2D2Protocol.expression(expression))
    }

    func playSequence(_ sequenceID: UInt16) {
        sendCommand(R2D2Protocol.highLevelSequence(sequenceID))
    }

    func stopAudio() {
        sendCommand(R2D2Protocol.stopSequences(flags: R2D2Protocol.StopFlags.audioPlaylist))
    }

    func stopSequences(flags: UInt8) {
        sendCommand(R2D2Protocol.stopSequences(flags: flags))
    }

    func powerDownToy() {
        sendRaw(R2D2Protocol.keepAlive)
        sendRaw(R2D2Protocol.powerDown)
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
