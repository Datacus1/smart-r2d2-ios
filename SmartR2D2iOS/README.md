# Smart R2-D2 iOS

Native SwiftUI/CoreBluetooth starter app for controlling a Hasbro Smart R2-D2 toy.

## Current Scope

- Scans for the toy's custom BLE service `DAB91435-B5A1-E29C-B041-BCD562613BE4`.
- Connects to the control characteristics found in the Android APK and confirmed with nRF Connect.
- Subscribes to main and radio notifications.
- Sends the recovered keepalive packet every 2 seconds.
- Includes first-pass controls for head position, LED color, basic motor direction, several audio playlists, stop audio, stop motion, and toy sleep.

## Opening In Xcode

Open:

```text
SmartR2D2iOS/SmartR2D2iOS.xcodeproj
```

Then:

1. Select the `SmartR2D2iOS` target.
2. Set your Apple development team under Signing & Capabilities.
3. Change the bundle identifier if Xcode asks for a unique one.
4. Run on a real iPhone. Bluetooth control will not work in the simulator.

## Build Without A Mac

This repo includes a GitHub Actions workflow at
`.github/workflows/build-ios-unsigned-ipa.yml`. Push the project to GitHub, open
the Actions tab, run `Build unsigned iOS IPA`, then download the
`SmartR2D2iOS-unsigned-ipa` artifact.

That artifact still needs to be signed before iOS will install it. From Windows,
the simplest test path is usually Sideloadly or AltStore/AltServer. Both require
an Apple ID and the usual iOS trust/developer-mode steps.

## First Test Pass

1. Turn the toy on.
2. Keep the drive wheels lifted or physically blocked for the first motor test.
3. Tap `Scan`.
4. Connect to `2ndHeroD`.
5. Try `Lights` and `Head` before `Drive`.
6. Enable `Drive`, then press and hold `Forward` or `Back`.

## No Mac Available

The iOS app itself still needs Apple's iOS toolchain to compile and install.
Without a Mac, use the Windows BLE tester at `../tools/windows-ble` to validate
the toy protocol first. Once the protocol is proven, the iOS build can be done
through a borrowed Mac or a cloud macOS build service.

## nRF Connect Manual Test

In nRF Connect, connect to `2ndHeroD`, enable notifications on
`DAB91382-B5A1-E29C-B041-BCD562613BE4`, then write byte arrays to
`DAB91383-B5A1-E29C-B041-BCD562613BE4`.

The original app sends keepalive every 2 seconds after connection. Manual
testing confirmed the toy accepts normal commands after the keepalive. Send one
keepalive first, then send the command quickly after it:

```text
Keep alive:             50 8D
Request input state:    20
LED blue:               15 00 FF
LED off:                15 00 00
Head right:             13 00
Head center:            13 01
Head left:              13 02
HL rotate head left:    17 02 6A 00
HL rotate head right:   17 02 6B 00
Stop all:               18 3F
```

If `15 00 FF` does not change the light after `50 8D`, the issue is connection
session/write behavior rather than the head command specifically.

## BLE Notes

```text
Service:      DAB91435-B5A1-E29C-B041-BCD562613BE4
Notify:       DAB91382-B5A1-E29C-B041-BCD562613BE4
Write:        DAB91383-B5A1-E29C-B041-BCD562613BE4
Radio notify: DAB90756-B5A1-E29C-B041-BCD562613BE4
Radio write:  DAB90757-B5A1-E29C-B041-BCD562613BE4
```

Recovered control packets:

```text
Keep alive:       50 8D
Power down:       50 91
End app mode:     50 8C
Head right:       13 00
Head center:      13 01
Head left:        13 02
Motor stop:       14 00
Motor forward:    14 01
Motor backward:   14 02
LED red:          15 FF 00
LED blue:         15 00 FF
LED off:          15 00 00
Play playlist N:  10 LL HH
Start sequence:   17 TYPE LL HH
Stop sequence:    18 FLAGS
```
