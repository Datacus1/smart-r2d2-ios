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

    enum DriveDirection: UInt16, CaseIterable, Identifiable {
        case forward = 1000
        case backward = 1001
        case forwardLeft = 1002
        case forwardRight = 1003
        case backwardLeft = 1004
        case backwardRight = 1005

        var id: UInt16 { rawValue }

        var title: String {
            switch self {
            case .forward: return "Forward"
            case .backward: return "Backward"
            case .forwardRight: return "Forward Right"
            case .forwardLeft: return "Forward Left"
            case .backwardRight: return "Backward Right"
            case .backwardLeft: return "Backward Left"
            }
        }

        var symbolName: String {
            switch self {
            case .forward: return "arrow.up"
            case .backward: return "arrow.down"
            case .forwardRight: return "arrow.up.right"
            case .forwardLeft: return "arrow.up.left"
            case .backwardRight: return "arrow.down.right"
            case .backwardLeft: return "arrow.down.left"
            }
        }
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

    enum Expression: UInt16, CaseIterable, Identifiable {
        case happy = 274
        case sad = 293
        case surprise = 303
        case music = 453

        var id: UInt16 { rawValue }

        var title: String {
            switch self {
            case .happy: return "Mood"
            case .sad: return "Sounds"
            case .surprise: return "FX"
            case .music: return "Music"
            }
        }

        var symbolName: String {
            switch self {
            case .happy: return "face.smiling"
            case .sad: return "cloud.rain.fill"
            case .surprise: return "burst.fill"
            case .music: return "music.note"
            }
        }
    }

    struct SequenceOption: Identifiable, Hashable {
        let title: String
        let sequenceID: UInt16
        let symbolName: String

        var id: UInt16 { sequenceID }
    }

    struct SequenceGroup: Identifiable, Hashable {
        let title: String
        let ids: [UInt16]
        let symbolName: String

        var id: String { title }
    }

    struct PlaylistOption: Identifiable, Hashable {
        let title: String
        let playlistID: UInt16
        let symbolName: String

        var id: UInt16 { playlistID }
    }

    struct StopOption: Identifiable, Hashable {
        let title: String
        let flags: UInt8
        let symbolName: String

        var id: UInt8 { flags }
    }

    static let headAnimationActions = [
        SequenceOption(title: "Rotate Head Left", sequenceID: 106, symbolName: "arrow.counterclockwise"),
        SequenceOption(title: "Rotate Head Right", sequenceID: 107, symbolName: "arrow.clockwise")
    ]

    static let shuffleActions = [
        SequenceOption(title: "Shuffle Back", sequenceID: 111, symbolName: "backward.fill"),
        SequenceOption(title: "Shuffle Forward", sequenceID: 141, symbolName: "forward.fill"),
        SequenceOption(title: "Shuffle In Place", sequenceID: 170, symbolName: "arrow.triangle.2.circlepath")
    ]

    static let lightSequenceActions = [
        SequenceOption(title: "Blue Flash", sequenceID: 3, symbolName: "bolt.fill"),
        SequenceOption(title: "Blue to Red", sequenceID: 15, symbolName: "arrow.left.arrow.right"),
        SequenceOption(title: "Red to Blue", sequenceID: 25, symbolName: "arrow.left.arrow.right"),
        SequenceOption(title: "Red Flash", sequenceID: 96, symbolName: "bolt.fill")
    ]

    static let utilityActions = [
        SequenceOption(title: "Alarm", sequenceID: 1, symbolName: "alarm.fill"),
        SequenceOption(title: "Berserk", sequenceID: 2, symbolName: "flame.fill"),
        SequenceOption(title: "Celebrate", sequenceID: 13, symbolName: "star.fill"),
        SequenceOption(title: "Interface", sequenceID: 14, symbolName: "terminal.fill"),
        SequenceOption(title: "Overload", sequenceID: 95, symbolName: "exclamationmark.triangle.fill"),
        SequenceOption(title: "Runaway", sequenceID: 108, symbolName: "figure.run"),
        SequenceOption(title: "Scanner", sequenceID: 109, symbolName: "viewfinder")
    ]

    static let expressionGroups = [
        SequenceGroup(title: "Affection", ids: [260, 262, 263, 264, 265, 266, 267, 268, 269, 261], symbolName: "heart.fill"),
        SequenceGroup(title: "Happy", ids: [274, 276, 277, 278, 279, 280, 281, 282, 275], symbolName: "face.smiling"),
        SequenceGroup(title: "Laughing", ids: [283, 285, 286, 287, 288, 289, 290, 291, 292, 284], symbolName: "quote.bubble.fill"),
        SequenceGroup(title: "Sad", ids: [293, 295, 296, 297, 298, 299, 300, 301, 302, 294], symbolName: "cloud.rain.fill"),
        SequenceGroup(title: "Surprise", ids: [303, 305, 306, 307, 473, 462, 463, 308, 309, 304], symbolName: "burst.fill"),
        SequenceGroup(title: "Afraid", ids: [461, 271, 272, 273, 468, 469, 470, 464, 465, 270], symbolName: "exclamationmark.triangle.fill"),
        SequenceGroup(title: "Talk", ids: [323, 310, 311, 312, 313, 314, 315, 316, 317, 413], symbolName: "bubble.left.and.bubble.right.fill")
    ]

    static let danceAndAmbientGroups = [
        SequenceGroup(title: "Dance", ids: Array(UInt16(419)...UInt16(434)), symbolName: "figure.walk.motion"),
        SequenceGroup(title: "Excited Dance", ids: Array(UInt16(368)...UInt16(379)), symbolName: "sparkles"),
        SequenceGroup(title: "Songs", ids: Array(UInt16(453)...UInt16(460)), symbolName: "speaker.wave.2.fill"),
        SequenceGroup(title: "Bored", ids: Array(UInt16(360)...UInt16(367)), symbolName: "moon.zzz.fill"),
        SequenceGroup(title: "Hanging Out", ids: Array(UInt16(395)...UInt16(404)), symbolName: "sparkles"),
        SequenceGroup(title: "Look Around", ids: Array(UInt16(408)...UInt16(417)), symbolName: "eye.fill"),
        SequenceGroup(title: "Obstacle", ids: Array(UInt16(435)...UInt16(444)), symbolName: "exclamationmark.octagon.fill"),
        SequenceGroup(title: "Relieved", ids: Array(UInt16(445)...UInt16(452)), symbolName: "checkmark.circle.fill"),
        SequenceGroup(title: "Startled", ids: Array(UInt16(461)...UInt16(473)), symbolName: "bolt.fill"),
        SequenceGroup(title: "Wakeup", ids: Array(UInt16(475)...UInt16(477)), symbolName: "sun.max.fill")
    ]

    static let stopOptions = [
        StopOption(title: "Stop All", flags: StopFlags.all, symbolName: "stop.circle.fill"),
        StopOption(title: "Stop Audio", flags: StopFlags.audioPlaylist, symbolName: "speaker.slash.fill"),
        StopOption(title: "Stop Movement", flags: StopFlags.motorSequence | StopFlags.motor2, symbolName: "pause.circle.fill"),
        StopOption(title: "Stop Sequence", flags: StopFlags.highLevel, symbolName: "xmark.circle.fill"),
        StopOption(title: "Stop LEDs", flags: StopFlags.ledSequence, symbolName: "lightbulb.slash.fill")
    ]

    static let soundOptions: [PlaylistOption] = (0...174).map { index in
        let playlistID = UInt16(index)
        return PlaylistOption(
            title: soundTitle(for: playlistID),
            playlistID: playlistID,
            symbolName: soundSymbol(for: playlistID)
        )
    }

    static func head(_ position: HeadPosition) -> Data {
        Data([0x13, position.rawValue])
    }

    static func drive(_ direction: DriveDirection) -> Data {
        startSequence(type: .motor, index: direction.rawValue)
    }

    static var stopDrive: Data {
        stopSequences(flags: StopFlags.motorSequence | StopFlags.motor2)
    }

    static func led(_ color: LEDColor) -> Data {
        let duties = color.duties
        return Data([0x15, duties.red, duties.blue])
    }

    static func playPlaylist(_ index: UInt16) -> Data {
        Data([0x10, UInt8(index & 0x00FF), UInt8((index >> 8) & 0x00FF)])
    }

    static func expression(_ expression: Expression) -> Data {
        startSequence(type: .highLevel, index: expression.rawValue)
    }

    static func highLevelSequence(_ index: UInt16) -> Data {
        startSequence(type: .highLevel, index: index)
    }

    static func startSequence(type: SequenceType, index: UInt16) -> Data {
        Data([0x17, type.rawValue, UInt8(index & 0x00FF), UInt8((index >> 8) & 0x00FF)])
    }

    static func stopSequences(flags: UInt8 = StopFlags.all) -> Data {
        Data([0x18, flags & StopFlags.all])
    }

    private static func soundTitle(for playlistID: UInt16) -> String {
        switch playlistID {
        case 0...137: return "Babble \(playlistID)"
        case 138: return "Stationary Mode"
        case 139: return "Mobile Mode"
        case 140: return "Guard Mode"
        case 141: return "Guard Countdown"
        case 142: return "Is That You"
        case 143: return "Intruder Alarm Loop"
        case 144: return "Intruder Alarm Tail"
        case 145: return "Alarm Deactivated"
        case 146: return "Wake Up"
        case 147, 167: return "Force Control \(playlistID)"
        case 148...150: return "Humming \(playlistID)"
        case 151: return "Going to Sleep"
        case 152...156: return "Whistle \(playlistID)"
        case 157: return "Achievement"
        case 158...164: return "Droid Vocal \(playlistID)"
        case 165...166: return "Cantina \(playlistID)"
        case 168: return "Unlock Alarm"
        case 169: return "Unlock Scan"
        case 170: return "Unlock Interface"
        case 171: return "Unlock Celebrate"
        case 172: return "Unlock Overload"
        case 173: return "Unlock Runaway"
        case 174: return "Unlock Berserk"
        default: return "Sound \(playlistID)"
        }
    }

    private static func soundSymbol(for playlistID: UInt16) -> String {
        switch playlistID {
        case 143...145, 168: return "alarm.fill"
        case 152...156: return "music.note"
        case 165...166: return "music.quarternote.3"
        case 169: return "viewfinder"
        case 171: return "star.fill"
        default: return "speaker.wave.2.fill"
        }
    }
}

extension Data {
    var hexString: String {
        map { String(format: "%02X", $0) }.joined(separator: " ")
    }
}
