#!/usr/bin/env python3
"""Kleine, reproduzierbare Ca/Mg- und EC-Beitragsprüfung für diesen Grow.

Die Ausgabe ersetzt keinen EC-Messwert. Die EC-Faktoren sind die im Workspace
dokumentierten Näherungen für Haifa Cal GG und EPSO Top.
"""

from __future__ import annotations

import argparse
import math
import sys


WATER_CA_MG_L = 35.0
WATER_MG_MG_L = 11.4
HAIFA_CA_FRACTION = 0.189
EPSO_MG_FRACTION = 0.0965
HAIFA_EC_PER_G_L = 1.354
EPSO_EC_PER_G_L = 1.071
WATER_EC = 0.299
FLOWER_EC_MAX = 1.4
TARGET_CA_MG = 3.0


def positive(value: str) -> float:
    number = float(value)
    if not math.isfinite(number) or number <= 0:
        raise argparse.ArgumentTypeError("muss eine positive Zahl sein")
    return number


def non_negative(value: str) -> float:
    number = float(value)
    if not math.isfinite(number) or number < 0:
        raise argparse.ArgumentTypeError("muss null oder größer sein")
    return number


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Prüft elementares Ca:Mg und dokumentierte EC-Beiträge."
    )
    parser.add_argument("--liters", type=positive, required=True, help="Mischvolumen")
    parser.add_argument(
        "--haifa-g", type=non_negative, default=0.0, help="Haifa Cal GG in Gramm"
    )
    parser.add_argument(
        "--epso-g", type=non_negative, default=0.0, help="EPSO Top in Gramm"
    )
    parser.add_argument(
        "--measured-ec",
        type=non_negative,
        help="gemessene Gesamt-EC der fertigen Lösung in mS/cm",
    )
    args = parser.parse_args()

    ca = WATER_CA_MG_L + args.haifa_g * HAIFA_CA_FRACTION * 1000 / args.liters
    mg = WATER_MG_MG_L + args.epso_g * EPSO_MG_FRACTION * 1000 / args.liters
    ratio = ca / mg if mg else math.inf
    haifa_ec = args.haifa_g / args.liters * HAIFA_EC_PER_G_L
    epso_ec = args.epso_g / args.liters * EPSO_EC_PER_G_L
    estimated_ec = WATER_EC + haifa_ec + epso_ec

    print(f"Mischvolumen: {args.liters:.2f} L")
    print(f"Haifa Cal GG: {args.haifa_g:.3f} g ({args.haifa_g / args.liters:.3f} g/L)")
    print(f"EPSO Top:     {args.epso_g:.3f} g ({args.epso_g / args.liters:.3f} g/L)")
    print(f"Ca: {ca:.1f} mg/L · Mg: {mg:.1f} mg/L · Ca:Mg: {ratio:.2f}:1")
    print(f"Dokumentierter EC-Beitrag: Haifa +{haifa_ec:.2f} · EPSO +{epso_ec:.2f} mS/cm")
    print(
        f"EC-Schätzung ohne Basisdünger: {estimated_ec:.2f} mS/cm "
        "(Wasser + Haifa + EPSO)"
    )

    if abs(ratio - TARGET_CA_MG) <= 0.35:
        print("Ca:Mg-Band: OK (Ziel 3:1 ± 0,35)")
    else:
        print("Ca:Mg-Band: prüfen (Ziel 3:1 ± 0,35)")

    if args.measured_ec is None:
        print("Gesamt-EC: OFFEN — fertige Lösung messen; Basisdünger ist nicht eingerechnet.")
    elif args.measured_ec > FLOWER_EC_MAX:
        print(
            f"WARNUNG: gemessene Gesamt-EC {args.measured_ec:.2f} > "
            f"Blütenobergrenze {FLOWER_EC_MAX:.1f} mS/cm bei keinem Runoff."
        )
    else:
        print(f"Gesamt-EC: {args.measured_ec:.2f} mS/cm — unter der Blütenobergrenze.")

    return 0


if __name__ == "__main__":
    sys.exit(main())
