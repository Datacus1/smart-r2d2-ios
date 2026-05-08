import CoreBluetooth
import Foundation

enum R2D2Protocol {
    static let advertisedNames = ["2ndHeroD", "RFduino", "Kipps"]

    static let serviceUUID = CBUUID(string: "DAB91435-B5A1-E29C-B041-BCD562613BE4")
    static let notifyCharacteristicUUID = CBUUID(string: "DAB91382-B5A1-E29C-B041-BCD562613BE4")
    static let writeCharacteristicUUID = CBUUID(string: "DAB91383-B5A1-E29C-B041-BCD562613BE4")
    static let radioNotifyCharacteristicUUID = CBUUID(string: "DAB90756-B5A1-E29C-B041-BCD562613BE4")
    static let radioWriteCharacteristicUUID = CBUUID(string: "DAB90757-B5A1-E29C-B041-BCD562613BE4")

    static let keepAlive = Data([0x50, 0x8D])
    static let endAppMode = Data([0x50, 0x8C])
    static let powerDown = Data([0x50, 0x91])

    enum HeadPosition: UInt8, CaseIterable, Identifiable {
        case left = 2
        case center = 1
        case right = 0

        var id: UInt8 { rawValue }

        var title: String {
            switch self {
            case .left: return "Left"
            case .center: return "Center"
            case .right: return "Right"
            }
        }

        var symbolName: String {
            switch self {
            case .left: return "arrow.turn.up.left"
            case .center: return "dot.circle"
            case .right: return "arrow.turn.up.right"
            }
        }
    }

    enum DriveDirection: UInt16 {
        case forward = 1000
        case backward = 1001
        case forwardRight = 1002
        case forwardLeft = 1003
        case backwardRight = 1004
        case backwardLeft = 1005
    }

    enum SequenceType: UInt8 {
        case led = 0
        case motor = 1
        case highLevel = 2
    }

    enum LEDColor: String, CaseIterable, Identifiable {
        case off = "Off"
        case red = "Red"
        case blue = "Blue"

        var id: String { rawValue }

        var duties: (red: UInt8, blue: UInt8) {
            switch self {
            case .off: return (0x00, 0x00)
            case .red: return (0xFF, 0x00)
            case .blue: return (0x00, 0xFF)
            }
        }
    }

    enum StopFlags {
        static let highLevel: UInt8 = 1
        static let ledSequence: UInt8 = 2
        static let motorSequence: UInt8 = 4
        static let motor1: UInt8 = 8
        static let motor2: UInt8 = 16
        static let audioPlaylist: UInt8 = 32
        static let all: UInt8 = 63
    }

    enum Sound: UInt16, CaseIterable, Identifiable {
        case babble = 0
        case whistle = 152
        case wakeUp = 146
        case cantina = 165

        var id: UInt16 { rawValue }

        var title: String {
            switch self {
            case .babble: return "Babble"
            case .whistle: return "Whistle"
            case .wakeUp: return "Wake"
            case .cantina: return "Cantina"
            }
        }
    }

    static func head(_ position: HeadPosition) -> Data {
        Data([0x13, position.rawValue])
    }

    static func drive(_ direction: DriveDirection) -> Data {
        startSequence(type: .motor, index: direction.rawValue)
    }

    static var stopDrive: Data {
        stopSequences(flags: StopFlags.motorSequence | StopFlags.motor1)
    }

    static func led(_ color: LEDColor) -> Data {
        let duties = color.duties
        return Data([0x15, duties.red, duties.blue])
    }

    static func playPlaylist(_ index: UInt16) -> Data {
        Data([0x10, UInt8(index & 0x00FF), UInt8((index >> 8) & 0x00FF)])
    }

    static func startSequence(type: SequenceType, index: UInt16) -> Data {
        Data([0x17, type.rawValue, UInt8(index & 0x00FF), UInt8((index >> 8) & 0x00FF)])
    }

    static func stopSequences(flags: UInt8 = StopFlags.all) -> Data {
        Data([0x18, flags & StopFlags.all])
    }
}

extension Data {
    var hexString: String {
        map { String(format: "%02X", $0) }.joined(separator: " ")
    }
}
