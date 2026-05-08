# Smart R2-D2 iOS

Experimental native iPhone controller for the discontinued Hasbro Smart R2-D2 toy app.

The app uses SwiftUI and CoreBluetooth to connect to the toy's BLE service and send the recovered control packets. Current confirmed controls include:

- keepalive/session packet
- blue/off LED control
- head left/center/right
- wheel drive forward/backward sequence control

The iOS app source is in `SmartR2D2iOS/`. A GitHub Actions workflow can build an unsigned IPA artifact for sideload testing.

See `SmartR2D2iOS/README.md` for build and manual BLE testing notes.
