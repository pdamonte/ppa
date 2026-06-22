#!/usr/bin/env python3
import argparse
import glob
import re
import shlex
import subprocess
import sys


def shell_var(name, value):
    print(f"{name}={shlex.quote(str(value))}")


def parse_entities(text):
    matches = list(re.finditer(r"^- entity\s+\d+:\s+(.+?)\s+\(", text, re.M))
    entities = {}

    for idx, match in enumerate(matches):
        name = match.group(1)
        start = match.start()
        end = matches[idx + 1].start() if idx + 1 < len(matches) else len(text)
        block = text[start:end]
        node_match = re.search(r"device node name\s+(\S+)", block)
        entities[name] = {
            "name": name,
            "block": block,
            "node": node_match.group(1) if node_match else "",
        }

    return entities


def iter_links(block):
    current_pad = None

    for line in block.splitlines():
        pad_match = re.search(r"\bpad(\d+):\s+([A-Z_,]+)", line)
        if pad_match:
            current_pad = int(pad_match.group(1))
            continue

        link_match = re.search(r'(->|<-)\s+"([^"]+)":(\d+)\s+\[([^\]]*)\]', line)
        if not link_match or current_pad is None:
            continue

        yield {
            "direction": link_match.group(1),
            "local_pad": current_pad,
            "remote_entity": link_match.group(2),
            "remote_pad": int(link_match.group(3)),
            "flags": link_match.group(4),
        }


def read_topology(media_dev):
    result = subprocess.run(
        ["media-ctl", "-d", media_dev, "-p"],
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
    )
    if result.returncode != 0:
        output = result.stdout.strip() or "no output"
        raise ValueError(output)
    return result.stdout


def find_pipeline(media_dev, sensor_pattern, topology_text=None):
    text = topology_text if topology_text is not None else read_topology(media_dev)
    entities = parse_entities(text)
    sensor_re = re.compile(sensor_pattern, re.I)

    sensor = next((entity for entity in entities.values() if sensor_re.search(entity["name"])), None)
    if not sensor:
        raise ValueError(f"sensor matching {sensor_pattern!r} not found")

    sensor_links = [
        link for link in iter_links(sensor["block"])
        if link["direction"] == "->" and "CSI2" in link["remote_entity"]
    ]
    if not sensor_links:
        raise ValueError(f"no CSI2 link found for {sensor['name']}")

    sensor_link = next((link for link in sensor_links if "ENABLED" in link["flags"]), sensor_links[0])
    csi = entities.get(sensor_link["remote_entity"])
    if not csi:
        raise ValueError(f"CSI entity {sensor_link['remote_entity']!r} not found")

    capture_links = [
        link for link in iter_links(csi["block"])
        if link["direction"] == "->" and "ISYS Capture" in link["remote_entity"]
    ]
    if not capture_links:
        raise ValueError(f"no capture link found for {csi['name']}")

    capture_link = next((link for link in capture_links if "ENABLED" in link["flags"]), capture_links[0])
    capture = entities.get(capture_link["remote_entity"])
    if not capture:
        raise ValueError(f"capture entity {capture_link['remote_entity']!r} not found")

    if not sensor["node"]:
        raise ValueError(f"sensor node missing for {sensor['name']}")
    if not csi["node"]:
        raise ValueError(f"CSI node missing for {csi['name']}")
    if not capture["node"]:
        raise ValueError(f"capture node missing for {capture['name']}")

    return {
        "MEDIA_DEV": media_dev,
        "SENSOR_ENTITY": sensor["name"],
        "SENSOR_NODE": sensor["node"],
        "SENSOR_SOURCE_PAD": sensor_link["local_pad"],
        "CSI_ENTITY": csi["name"],
        "CSI_NODE": csi["node"],
        "CSI_SINK_PAD": sensor_link["remote_pad"],
        "CSI_SOURCE_PAD": capture_link["local_pad"],
        "CAPTURE_ENTITY": capture["name"],
        "CAPTURE_NODE": capture["node"],
        "CAPTURE_SINK_PAD": capture_link["remote_pad"],
    }


def media_devices(media_arg):
    if media_arg != "auto":
        return [media_arg]

    devices = sorted(glob.glob("/dev/media*"))
    devices.extend(f"/dev/{path.rsplit('/', 1)[-1]}" for path in sorted(glob.glob("/sys/class/media/*")))
    devices.extend(f"/dev/media{idx}" for idx in range(32))

    seen = set()
    return [dev for dev in devices if not (dev in seen or seen.add(dev))]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--media", default="auto")
    parser.add_argument("--sensor", required=True)
    parser.add_argument("--topology-file")
    args = parser.parse_args()

    if args.topology_file:
        with open(args.topology_file, encoding="utf-8") as topology_file:
            pipeline = find_pipeline(args.media, args.sensor, topology_file.read())
        for name, value in pipeline.items():
            shell_var(name, value)
        return 0

    errors = []
    for media_dev in media_devices(args.media):
        try:
            pipeline = find_pipeline(media_dev, args.sensor)
            for name, value in pipeline.items():
                shell_var(name, value)
            return 0
        except Exception as exc:
            errors.append(f"{media_dev}: {exc}")

    print("Unable to detect camera pipeline:", file=sys.stderr)
    for error in errors:
        print(f"  {error}", file=sys.stderr)
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
