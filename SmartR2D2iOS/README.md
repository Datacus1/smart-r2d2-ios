# Smart R2-D2 iOS

Native SwiftUI/CoreBluetooth starter app for controlling a Hasbro Smart R2-D2 toy.

## Current Scope

- Scans for the toy's custom BLE service `DAB91435-B5A1-E29C-B041-BCD562613BE4`.
- Connects to the control characteristics found in the Android APK and confirmed with nRF Connect.
- Subscribes to main and radio notifications.
- Sends the recovered keepalive packet every 2 seconds.
- Includes an old-app-style drive console with head controls, six-way drive,
  main-screen LED control, action catalogs, diagnostics, and explicit scan,
  connect, power-down, and disconnect controls.

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
2. Keep the drive wheels lifted or physically blocked for the first drive test.
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
Drive forward:          17 01 E8 03
Drive backward:         17 01 E9 03
Drive forward left:     17 01 EA 03
Drive forward right:    17 01 EB 03
Stop drive:             18 14
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
Drive forward:        17 01 E8 03
Drive backward:       17 01 E9 03
Drive forward left:   17 01 EA 03
Drive forward right:  17 01 EB 03
Drive backward left:  17 01 EC 03
Drive backward right: 17 01 ED 03
Stop drive:           18 14
LED red:          15 FF 00
LED blue:         15 00 FF
LED off:          15 00 00
Play playlist N:  10 LL HH
Start sequence:   17 TYPE LL HH
Stop sequence:    18 FLAGS
```

Useful high-level behavior sequence ranges recovered from the APK enum names:

```text
Bored:              360-367
Excited reaction:   368-379
Force reaction:     380-383
Freaked out:        384-390
Going to sleep:     391-392
Guard mode:         393-394
Hanging out:        395-404
Intruder alarm:     405-406
Is that you:        407
Look around:        408-417
Mobile hangout:     418
Music response:     419-434
Obstacle:           435-444
Relieved:           445-452
Songs/music:        453-460
Startled:           461-473
Stationary hangout: 474
Wakeup:             475-477
```

There is no recovered Bluetooth power-on packet. The toy must already be awake
and advertising before the app can scan or connect; `50 91` only powers it down
after a BLE session is active.

The Android APK's manual drive path stops with flag `18 14`. Direct opcode `14`
depends on the toy's internal cam/selector position, so this app currently keeps
using the safer recovered drive sequences for wheel movement.
