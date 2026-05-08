# Windows BLE Tester

This validates the Smart R2-D2 BLE protocol from Windows. It does not run the
iPhone app, but it tests the same UUIDs and command bytes.

## Setup

```powershell
python -m pip install bleak
```

## Scan

```powershell
python .\tools\windows-ble\r2d2_ble_test.py scan
```

Look for `2ndHeroD` or the advertised service:

```text
dab91435-b5a1-e29c-b041-bcd562613be4
```

## Safe First Commands

```powershell
python .\tools\windows-ble\r2d2_ble_test.py led blue
python .\tools\windows-ble\r2d2_ble_test.py led off
python .\tools\windows-ble\r2d2_ble_test.py head left
python .\tools\windows-ble\r2d2_ble_test.py head center
python .\tools\windows-ble\r2d2_ble_test.py sound whistle
```

## Drive Test

Lift the toy or block the wheels first.

```powershell
python .\tools\windows-ble\r2d2_ble_test.py drive forward --duration 0.5 --yes-drive
python .\tools\windows-ble\r2d2_ble_test.py drive left --duration 0.5 --yes-drive
python .\tools\windows-ble\r2d2_ble_test.py drive right --duration 0.5 --yes-drive
python .\tools\windows-ble\r2d2_ble_test.py stop
```

## Notes

The script writes to:

```text
DAB91383-B5A1-E29C-B041-BCD562613BE4
```

and sends keepalive every 2 seconds while connected:

```text
50 8D
```

Drive uses the recovered APK motor sequence packets, not direct opcode `14`.
On this toy, `14` appears to control the head motor.
