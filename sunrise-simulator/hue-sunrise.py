#!/usr/bin/env python3
"""
Hue Sunrise Simulator — Felix
Replicates natural morning light: warm/dim → bright/cool over 30 min.

Usage:
  1. Press the button on the Hue Bridge
  2. Run: python3 hue-sunrise.py --discover
  3. On future runs: python3 hue-sunrise.py

Controls a single light or group. Configure below or via CLI flags.
"""

import argparse
import json
import math
import os
import subprocess
import sys
import time
from datetime import datetime

import requests

# ── Defaults (override via CLI) ──────────────────────────────────────────────
CONFIG = {
    "bridge_ip": "10.0.100.22",         # auto-discovered if empty
    "username": None,                    # saved to ~/.hue-username after register
    "target": None,                      # "light:1" or "group:0" (0 = all lights)
    "duration_min": 30,                  # total ramp time
    "steps": 10,                         # number of transition segments
}

# Hue CT (mired) scale: 500 = 2000K (deep warm), 153 = ~6535K (cool white)
START_CT = 500    # 2000K — warm orange
END_CT   = 200    # 5000K — bright morning white

START_BRI = 2     # barely visible (1-254)
END_BRI   = 254   # full brightness

CONFIG_FILE = os.path.expanduser("~/.hue-sunrise-config.json")


# ── Helpers ──────────────────────────────────────────────────────────────────

def load_config():
    if os.path.exists(CONFIG_FILE):
        with open(CONFIG_FILE) as f:
            cfg = json.load(f)
            CONFIG.update(cfg)


def save_config():
    with open(CONFIG_FILE, "w") as f:
        json.dump(CONFIG, f, indent=2)


def http_put(path, data, bridge_ip=None):
    ip = bridge_ip or CONFIG["bridge_ip"]
    r = requests.put(f"http://{ip}/api/{CONFIG['username']}/{path}",
                     json.dumps(data), timeout=10)
    return r.json()


def http_get(path):
    r = requests.get(f"http://{CONFIG['bridge_ip']}/api/{CONFIG['username']}/{path}",
                     timeout=10)
    return r.json()


def lerp(a, b, t):
    """Linearly interpolate a → b by factor t (0.0 - 1.0)."""
    return int(a + (b - a) * t)


# ── Commands ─────────────────────────────────────────────────────────────────

def cmd_discover():
    """Find Hue bridges on the local network."""
    try:
        r = requests.get("https://discovery.meethue.com/", timeout=5)
        bridges = r.json()
        if not bridges:
            print("❌ No Hue bridges found.")
            return False
        for b in bridges:
            print(f"  Bridge {b['id']} at {b['internalipaddress']}:{b.get('port', 443)}")
        if len(bridges) == 1:
            CONFIG["bridge_ip"] = bridges[0]["internalipaddress"]
            save_config()
            print(f"\n→ Saved bridge IP: {CONFIG['bridge_ip']}")
        return True
    except Exception as e:
        print(f"❌ Discovery failed: {e}")
        print("   Provide bridge IP manually: --bridge 10.0.0.X")
        return False


def cmd_register():
    """Register API user with the bridge (press button first!)."""
    print("🔘 Press the button on your Hue Bridge, then press Enter...")
    input()
    try:
        r = requests.post(f"http://{CONFIG['bridge_ip']}/api",
                          json={"devicetype": "felix_sunrise"}, timeout=5)
        result = r.json()[0]
        if "success" in result:
            CONFIG["username"] = result["success"]["username"]
            save_config()
            print(f"✅ Registered! Username: {CONFIG['username']}")
            return True
        else:
            err = result.get("error", {})
            print(f"❌ {err.get('description', 'Unknown error')}")
            return False
    except Exception as e:
        print(f"❌ Connection failed: {e}")
        return False


def cmd_list_lights():
    """List all lights and groups available on the bridge."""
    if not CONFIG["username"]:
        print("❌ Not registered. Run: python3 hue-sunrise.py --register")
        return

    lights = http_get("lights")
    if "error" in lights:
        print(f"❌ Bridge error: {lights['error'][0]['description']}")
        return

    print("\n💡 Lights:")
    for lid, info in lights.items():
        state = info.get("state", {})
        on = "🟢" if state.get("on") else "⚫"
        bri = state.get("bri", "?")
        ct = state.get("ct", "?")
        print(f"  {on} Light {lid}: {info['name']} (bri={bri}, ct={ct})")

    groups = http_get("groups")
    print("\n📦 Groups:")
    for gid, info in groups.items():
        print(f"  Group {gid}: {info.get('name', 'unnamed')} "
              f"({len(info.get('lights', []))} lights)")


def cmd_test():
    """Quick blink test on the target light to verify everything works."""
    if not CONFIG["target"]:
        print("❌ No target set. Use --light or --group.")
        return

    kind, target_id = CONFIG["target"].split(":")
    print(f"🔦 Testing {kind} {target_id}…")

    payload = {"on": True, "bri": 254, "ct": 366, "alert": "lselect"}
    if kind == "group":
        payload["group"] = target_id
        print(http_put(f"groups/{target_id}/action", payload))
    else:
        print(http_put(f"lights/{target_id}/state", payload))

    print("✅ Check your light — it should blink twice.")
    time.sleep(3)
    # Restore — just turn on dim warm
    payload = {"on": True, "bri": 50, "ct": 500, "alert": "none"}
    if kind == "group":
        print(http_put(f"groups/{target_id}/action", payload))
    else:
        print(http_put(f"lights/{target_id}/state", payload))


def cmd_sunrise():
    """Run the sunrise sequence."""
    if not CONFIG["target"]:
        print("❌ No target set. Use --light or --group.")
        return

    kind, target_id = CONFIG["target"].split(":")
    steps = CONFIG["steps"]
    total_sec = CONFIG["duration_min"] * 60
    seg_sec = total_sec // steps  # seconds per segment
    trans_decisec = seg_sec * 10  # Hue API uses deciseconds (100ms units)

    print(f"\n🌅 Starting sunrise on {kind} {target_id}")
    print(f"   Duration: {CONFIG['duration_min']} min ({steps} steps)")
    print(f"   {START_CT}mired ({round(1e6/START_CT)}K) → {END_CT}mired ({round(1e6/END_CT)}K)")
    start_time = datetime.now()

    # Step 0: Turn on at starting values, instant
    print(f"   [{datetime.now().strftime('%H:%M:%S')}] Step 0/0: instant-on @ warm+dɪm")
    payload = {"on": True, "bri": START_BRI, "ct": START_CT, "transitiontime": 0}
    if kind == "group":
        http_put(f"groups/{target_id}/action", payload)
    else:
        http_put(f"lights/{target_id}/state", payload)

    time.sleep(1)  # give the bridge a moment

    # Steps 1..N: gradual increase
    for step in range(1, steps + 1):
        t = step / steps  # 0.1 → 1.0
        bri = lerp(START_BRI, END_BRI, t)
        ct = lerp(START_CT, END_CT, t)
        payload = {"bri": bri, "ct": ct, "transitiontime": trans_decisec}

        print(f"   [{datetime.now().strftime('%H:%M:%S')}] Step {step}/{steps}: "
              f"bri={bri}, ct={ct} ({round(1e6/ct)}K) "
              f"[transition={trans_decisec}ds = {seg_sec}s]")

        if kind == "group":
            http_put(f"groups/{target_id}/action", payload)
        else:
            http_put(f"lights/{target_id}/state", payload)

        # Wait for this segment to finish (minus a small margin)
        time.sleep(max(1, seg_sec - 1))

    elapsed = (datetime.now() - start_time).total_seconds()
    print(f"\n✅ Sunrise complete ({elapsed:.0f}s elapsed)")


# ── CLI ──────────────────────────────────────────────────────────────────────

def main():
    load_config()

    parser = argparse.ArgumentParser(
        description="Hue Sunrise Simulator — gentle wake from warm dim to cool bright",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python3 hue-sunrise.py --discover          # find bridge on network
  python3 hue-sunrise.py --register          # press bridge button first!
  python3 hue-sunrise.py --list              # see all lights/groups
  python3 hue-sunrise.py --light 1 --test    # blink Light 1
  python3 hue-sunrise.py --group 0           # sunrise on all lights
  python3 hue-sunrise.py --light 2           # sunrise on Light 2
  python3 hue-sunrise.py --duration 45       # 45-minute sunrise
        """
    )

    op = parser.add_argument_group("operations (mutually exclusive)")
    op.add_argument("--discover", action="store_true", help="Scan for Hue bridges")
    op.add_argument("--register", action="store_true", help="Register with bridge (press button!)")
    op.add_argument("--list", action="store_true", help="List lights and groups")
    op.add_argument("--test", action="store_true", help="Blink test the target")
    # (no flag = sunrise mode)

    cfg = parser.add_argument_group("configuration")
    cfg.add_argument("--bridge", help=f"Bridge IP (default: {CONFIG['bridge_ip']})")
    cfg.add_argument("--light", type=int, help="Light ID to control")
    cfg.add_argument("--group", type=int, help="Group ID to control")
    cfg.add_argument("--duration", type=int, help=f"Ramp duration in minutes (default: {CONFIG['duration_min']})")
    cfg.add_argument("--steps", type=int, help=f"Transition steps (default: {CONFIG['steps']})")

    args = parser.parse_args()

    # Apply CLI overrides
    if args.bridge:
        CONFIG["bridge_ip"] = args.bridge
    if args.light is not None:
        CONFIG["target"] = f"light:{args.light}"
    elif args.group is not None:
        CONFIG["target"] = f"group:{args.group}"
    if args.duration:
        CONFIG["duration_min"] = args.duration
    if args.steps:
        CONFIG["steps"] = args.steps

    # Save any config changes from the command line
    save_config()

    # Dispatch
    if args.discover:
        cmd_discover()
    elif args.register:
        cmd_register()
    elif args.list:
        cmd_list_lights()
    elif args.test:
        cmd_test()
    else:
        # Sunrise mode
        if not CONFIG["username"]:
            print("❌ Not registered. Run: python3 hue-sunrise.py --register")
            sys.exit(1)
        if not CONFIG["target"]:
            print("❌ No target set. Use --light or --group.")
            print("   See: python3 hue-sunrise.py --list")
            sys.exit(1)
        cmd_sunrise()


if __name__ == "__main__":
    main()
