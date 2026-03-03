"""
SYS_ADMIN Test Analyzer
JSON test sonuçlarını okur, analiz eder, grafik çizer.

Kullanım:
    python analyzer.py                          # En son sonucu otomatik bul
    python analyzer.py path/to/results.json     # Belirli dosyayı analiz et
    python analyzer.py --no-charts              # Sadece konsol raporu
"""

import json
import sys
import os
from pathlib import Path


def load_data(filepath):
    with open(filepath, "r", encoding="utf-8") as f:
        return json.load(f)


def print_summary(data):
    snapshots = data.get("snapshots", [])
    print(f"\n{'='*60}")
    print(f"  Scenario: {data.get('scenario', '?')}")
    print(f"  Ticks: {data.get('total_ticks', 0)}  |  Snapshots: {data.get('snapshot_count', 0)}")
    print(f"{'='*60}")

    if not snapshots:
        print("  No snapshots to analyze.")
        return

    first = snapshots[0]
    last = snapshots[-1]

    # Credits
    c_first = first.get("credits", 0)
    c_last = last.get("credits", 0)
    tick_diff = max(1, last.get("tick", 1) - first.get("tick", 0))
    rate = (c_last - c_first) / tick_diff
    print(f"\n  Credits: {c_first:.0f} -> {c_last:.0f}  (rate: {rate:.2f} CR/tick)")

    # Global stats
    g = last.get("global", {})
    print(f"\n  Buildings: {g.get('building_count', 0)}")
    print(f"  Working: {g.get('working_count', 0)}  |  Overheated: {g.get('overheated_count', 0)}  |  Unpowered: {g.get('unpowered_count', 0)}")
    print(f"  Total heat: {g.get('total_heat', 0):.1f}  |  Total stored: {g.get('total_stored', 0)} MB")
    print(f"  Connections: {g.get('connection_count', 0)}")

    # Labeled snapshots
    labeled = [s for s in snapshots if s.get("label", "")]
    if labeled:
        print(f"\n  Labeled Snapshots:")
        for s in labeled:
            sg = s.get("global", {})
            print(f"    [{s['label']}] tick={s['tick']}  credits={s.get('credits', 0):.0f}  heat={sg.get('total_heat', 0):.1f}  stored={sg.get('total_stored', 0)}MB")

    # Problems
    problems = []
    for b in last.get("buildings", []):
        if b.get("is_overheated", False):
            problems.append(f"    OVERHEAT: {b['name']} at ({b['cell'][0]},{b['cell'][1]}) — {b['heat']:.1f}/{b['heat_max']:.0f} C")
        if not b.get("has_power", True) and b.get("type") not in ["power", "coolant"]:
            problems.append(f"    NO POWER: {b['name']} at ({b['cell'][0]},{b['cell'][1]})")
        cap = b.get("storage_capacity", 0)
        if cap > 0 and b.get("total_stored", 0) >= cap:
            problems.append(f"    FULL: {b['name']} at ({b['cell'][0]},{b['cell'][1]}) — {b['total_stored']}/{cap} MB")

    if problems:
        print(f"\n  PROBLEMS ({len(problems)}):")
        for p in problems:
            print(p)
    else:
        print(f"\n  No problems detected.")

    print(f"\n{'='*60}")


def plot_charts(data, output_dir=None):
    try:
        import matplotlib.pyplot as plt
    except ImportError:
        print("\n  matplotlib not installed. Run: pip install matplotlib")
        return

    snapshots = data.get("snapshots", [])
    if len(snapshots) < 2:
        print("  Not enough snapshots for charts.")
        return

    ticks = [s["tick"] for s in snapshots]
    credits = [s["credits"] for s in snapshots]
    total_heat = [s["global"]["total_heat"] for s in snapshots]
    total_stored = [s["global"]["total_stored"] for s in snapshots]
    overheated = [s["global"]["overheated_count"] for s in snapshots]
    working = [s["global"]["working_count"] for s in snapshots]

    fig, axes = plt.subplots(2, 2, figsize=(14, 10))
    fig.suptitle(f"SYS_ADMIN — {data.get('scenario', '?')}", fontsize=14, fontweight="bold")

    # Credits
    axes[0][0].plot(ticks, credits, color="#00cc66", linewidth=2)
    axes[0][0].set_title("Credits Over Time")
    axes[0][0].set_xlabel("Tick")
    axes[0][0].set_ylabel("Credits")
    axes[0][0].grid(True, alpha=0.3)

    # Heat
    axes[0][1].plot(ticks, total_heat, color="#ff6644", linewidth=2)
    axes[0][1].set_title("Total Heat Over Time")
    axes[0][1].set_xlabel("Tick")
    axes[0][1].set_ylabel("Total Heat (C)")
    axes[0][1].grid(True, alpha=0.3)

    # Storage
    axes[1][0].plot(ticks, total_stored, color="#44aaff", linewidth=2)
    axes[1][0].set_title("Total Stored Data Over Time")
    axes[1][0].set_xlabel("Tick")
    axes[1][0].set_ylabel("Total Stored (MB)")
    axes[1][0].grid(True, alpha=0.3)

    # Working vs Overheated
    axes[1][1].plot(ticks, working, color="#00cc66", label="Working", linewidth=2)
    axes[1][1].plot(ticks, overheated, color="#ff4422", label="Overheated", linewidth=2)
    axes[1][1].set_title("Building Status Over Time")
    axes[1][1].set_xlabel("Tick")
    axes[1][1].legend()
    axes[1][1].grid(True, alpha=0.3)

    plt.tight_layout()

    if output_dir:
        out_path = os.path.join(output_dir, f"{data.get('scenario', 'result')}_charts.png")
        plt.savefig(out_path, dpi=150)
        print(f"\n  Charts saved: {out_path}")
    else:
        plt.show()


def find_latest_result():
    """Find the most recent test result JSON in Godot's user:// directory."""
    # Windows: %APPDATA%/Godot/app_userdata/<project>/test_results/
    appdata = os.environ.get("APPDATA", "")
    possible_dirs = [
        os.path.join(appdata, "Godot", "app_userdata", "SYS_ADMIN", "test_results"),
        os.path.join(appdata, "Godot", "app_userdata", "sys-admin", "test_results"),
    ]

    for d in possible_dirs:
        if os.path.exists(d):
            files = sorted(Path(d).glob("*.json"), key=os.path.getmtime, reverse=True)
            if files:
                return str(files[0])
    return None


def main():
    no_charts = "--no-charts" in sys.argv
    args = [a for a in sys.argv[1:] if not a.startswith("--")]

    if args:
        filepath = args[0]
    else:
        filepath = find_latest_result()
        if filepath:
            print(f"  Auto-detected: {filepath}")
        else:
            print("  No test results found.")
            print("  Usage: python analyzer.py <path_to_json>")
            print("  Or run a scenario in Godot first.")
            return

    if not os.path.exists(filepath):
        print(f"  File not found: {filepath}")
        return

    data = load_data(filepath)
    print_summary(data)

    if not no_charts:
        plot_charts(data)


if __name__ == "__main__":
    main()
