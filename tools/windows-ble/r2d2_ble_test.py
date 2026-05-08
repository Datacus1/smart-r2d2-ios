#!/usr/bin/env python3
"""Windows BLE tester for the Hasbro Smart R2-D2 toy.

This script validates the BLE protocol used by the iOS app without needing a
Mac. It uses bleak, which talks to Windows Bluetooth through WinRT.
"""

from __future__ import annotations

import argparse
import asyncio
import contextlib
import sys
from dataclasses import dataclass
from typing import Iterable

try:
    from bleak import BleakClient, BleakScanner
    from bleak.backends.device import BLEDevice
    from bleak.backends.scanner import AdvertisementData
except ImportError as exc:  # pragma: no cover - friendlier CLI error
    raise SystemExit(
        "Missing dependency: bleak\n"
        "Install it with:\n"
        "  python -m pip install bleak\n"
    ) from exc


SERVICE_UUID = "dab91435-b5a1-e29c-b041-bcd562613be4"
NOTIFY_UUID = "dab91382-b5a1-e29c-b041-bcd562613be4"
WRITE_UUID = "dab91383-b5a1-e29c-b041-bcd562613be4"
RADIO_NOTIFY_UUID = "dab90756-b5a1-e29c-b041-bcd562613be4"
RADIO_WRITE_UUID = "dab90757-b5a1-e29c-b041-bcd562613be4"

KNOWN_NAMES = {"2ndHeroD", "RFduino", "Kipps"}
KEEPALIVE = bytes([0x50, 0x8D])
END_APP_MODE = bytes([0x50, 0x8C])
POWER_DOWN = bytes([0x50, 0x91])

HEAD = {
    "left": bytes([0x13, 0x02]),
    "center": bytes([0x13, 0x01]),
    "right": bytes([0x13, 0x00]),
}

DRIVE = {
    "stop": bytes([0x18, 0x0C]),
    "forward": bytes([0x17, 0x01, 0xE8, 0x03]),
    "backward": bytes([0x17, 0x01, 0xE9, 0x03]),
    "right": bytes([0x17, 0x01, 0xEA, 0x03]),
    "left": bytes([0x17, 0x01, 0xEB, 0x03]),
    "backward-right": bytes([0x17, 0x01, 0xEC, 0x03]),
    "backward-left": bytes([0x17, 0x01, 0xED, 0x03]),
}

LED = {
    "off": bytes([0x15, 0x00, 0x00]),
    "red": bytes([0x15, 0xFF, 0x00]),
    "blue": bytes([0x15, 0x00, 0xFF]),
}

SOUNDS = {
    "babble": 0,
    "whistle": 152,
    "wake": 146,
    "cantina": 165,
}


@dataclass(frozen=True)
class Candidate:
    device: BLEDevice
    advertisement: AdvertisementData

    @property
    def name(self) -> str:
        return self.advertisement.local_name or self.device.name or "Unnamed"

    @property
    def service_uuids(self) -> list[str]:
        return [uuid.lower() for uuid in (self.advertisement.service_uuids or [])]

    @property
    def is_r2d2(self) -> bool:
        return SERVICE_UUID in self.service_uuids or self.name in KNOWN_NAMES


def hex_bytes(data: bytes | bytearray | memoryview) -> str:
    return " ".join(f"{byte:02X}" for byte in bytes(data))


def parse_raw_hex(value: str) -> bytes:
    cleaned = value.replace("0x", "").replace(",", " ").replace("-", " ")
    parts = cleaned.split()
    if not parts:
        raise argparse.ArgumentTypeError("raw packet cannot be empty")

    try:
        data = bytes(int(part, 16) for part in parts)
    except ValueError as exc:
        raise argparse.ArgumentTypeError(f"invalid hex byte in {value!r}") from exc

    if any(byte > 0xFF for byte in data):
        raise argparse.ArgumentTypeError("hex values must be bytes")
    return data


def playlist_packet(index: int) -> bytes:
    if index < 0 or index > 0xFFFF:
        raise ValueError("playlist index must fit in UInt16")
    return bytes([0x10, index & 0xFF, (index >> 8) & 0xFF])


def stop_sequences(flags: int = 63) -> bytes:
    return bytes([0x18, flags & 0x3F])


async def scan(seconds: float) -> list[Candidate]:
    print(f"Scanning for {seconds:g}s...")
    discovered = await BleakScanner.discover(
        timeout=seconds,
        return_adv=True,
        service_uuids=[SERVICE_UUID],
    )

    candidates = [
        Candidate(device=device, advertisement=adv)
        for device, adv in discovered.values()
    ]

    if not candidates:
        # Some Windows adapters are picky about service-filtered scans.
        print("No service-filtered results; trying a broad scan...")
        discovered = await BleakScanner.discover(timeout=seconds, return_adv=True)
        candidates = [
            Candidate(device=device, advertisement=adv)
            for device, adv in discovered.values()
        ]

    return sorted(candidates, key=lambda item: (not item.is_r2d2, item.name))


async def find_toy(address: str | None, seconds: float) -> BLEDevice:
    if address:
        return BLEDevice(address=address, name=address, details=None)

    candidates = await scan(seconds)
    print_candidates(candidates)

    for candidate in candidates:
        if candidate.is_r2d2:
            print(f"Using {candidate.name} ({candidate.device.address})")
            return candidate.device

    raise SystemExit("Could not find Smart R2-D2. Turn it on and keep it near this PC.")


def print_candidates(candidates: Iterable[Candidate]) -> None:
    for candidate in candidates:
        marker = "*" if candidate.is_r2d2 else " "
        uuids = ", ".join(candidate.service_uuids) or "no advertised services"
        print(f"{marker} {candidate.name:24} {candidate.device.address:24} RSSI={candidate.advertisement.rssi} {uuids}")


async def keepalive_loop(client: BleakClient, stop_event: asyncio.Event) -> None:
    while not stop_event.is_set():
        await client.write_gatt_char(WRITE_UUID, KEEPALIVE, response=False)
        print(f"TX keepalive {hex_bytes(KEEPALIVE)}")
        with contextlib.suppress(asyncio.TimeoutError):
            await asyncio.wait_for(stop_event.wait(), timeout=2.0)


async def run_command(args: argparse.Namespace) -> None:
    device = await find_toy(args.address, args.scan_seconds)
    stop_keepalive = asyncio.Event()

    async with BleakClient(device) as client:
        print(f"Connected: {client.is_connected}")

        def notify(label: str):
            def _handler(_: int, data: bytearray) -> None:
                print(f"{label} {hex_bytes(data)}")
            return _handler

        for uuid, label in ((NOTIFY_UUID, "RX"), (RADIO_NOTIFY_UUID, "RADIO RX")):
            try:
                await client.start_notify(uuid, notify(label))
                print(f"Subscribed {uuid}")
            except Exception as exc:
                print(f"Could not subscribe {uuid}: {exc}")

        keepalive_task = asyncio.create_task(keepalive_loop(client, stop_keepalive))

        try:
            await asyncio.sleep(args.settle)
            packets = build_packets(args)
            for packet in packets:
                await client.write_gatt_char(WRITE_UUID, packet, response=False)
                print(f"TX {hex_bytes(packet)}")
                await asyncio.sleep(args.gap)

            if args.command == "drive" and args.drive_direction != "stop":
                await asyncio.sleep(args.duration)
                await client.write_gatt_char(WRITE_UUID, DRIVE["stop"], response=False)
                print(f"TX auto-stop {hex_bytes(DRIVE['stop'])}")
        finally:
            stop_keepalive.set()
            await keepalive_task


def build_packets(args: argparse.Namespace) -> list[bytes]:
    match args.command:
        case "head":
            return [HEAD[args.position]]
        case "led":
            return [LED[args.color]]
        case "drive":
            if args.drive_direction != "stop" and not args.yes_drive:
                raise SystemExit("Drive commands require --yes-drive. Lift/block the toy first.")
            return [DRIVE[args.drive_direction]]
        case "sound":
            return [playlist_packet(SOUNDS[args.sound])]
        case "playlist":
            return [playlist_packet(args.index)]
        case "stop":
            return [DRIVE["stop"], stop_sequences(63)]
        case "sleep":
            return [KEEPALIVE, POWER_DOWN]
        case "raw":
            return [args.packet]
        case _:
            raise SystemExit(f"Unknown command: {args.command}")


async def main() -> None:
    parser = argparse.ArgumentParser(description="Test Smart R2-D2 BLE packets from Windows.")
    parser.add_argument("--address", help="Connect to a known BLE address instead of scanning.")
    parser.add_argument("--scan-seconds", type=float, default=8.0)
    parser.add_argument("--settle", type=float, default=0.4, help="Delay after connecting before command TX.")
    parser.add_argument("--gap", type=float, default=0.15, help="Delay between command packets.")

    subparsers = parser.add_subparsers(dest="command", required=True)
    subparsers.add_parser("scan", help="Scan and list nearby BLE peripherals.")

    head = subparsers.add_parser("head", help="Move R2-D2's head.")
    head.add_argument("position", choices=sorted(HEAD))

    led = subparsers.add_parser("led", help="Set the red/blue logic LED.")
    led.add_argument("color", choices=sorted(LED))

    drive = subparsers.add_parser("drive", help="Run the wheel drive sequence briefly.")
    drive.add_argument("drive_direction", choices=sorted(DRIVE))
    drive.add_argument("--duration", type=float, default=0.5)
    drive.add_argument("--yes-drive", action="store_true", help="Required for any movement.")

    sound = subparsers.add_parser("sound", help="Play a known audio playlist.")
    sound.add_argument("sound", choices=sorted(SOUNDS))

    playlist = subparsers.add_parser("playlist", help="Play a raw playlist index.")
    playlist.add_argument("index", type=int)

    subparsers.add_parser("stop", help="Stop motion and sequences.")
    subparsers.add_parser("sleep", help="Send the recovered power-down packet.")

    raw = subparsers.add_parser("raw", help="Write raw hex bytes to the main write characteristic.")
    raw.add_argument("packet", type=parse_raw_hex)

    args = parser.parse_args()

    if args.command == "scan":
        print_candidates(await scan(args.scan_seconds))
    else:
        await run_command(args)


if __name__ == "__main__":
    if sys.platform != "win32":
        print("This tester is intended for Windows BLE, but bleak may work here too.")
    asyncio.run(main())
