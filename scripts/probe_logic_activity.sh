#!/usr/bin/env bash
# Logic analyzer activity probe (DIAGNOSTIC — not a pass/fail evidence step).
#
# Captures the raw digital channels and reports per-channel transition counts
# and idle level. This is the first-pass triage when an I2C/UART decode fails:
# it shows which probe wire is actually carrying signal, independent of any
# protocol decoder. For example, "SDA active but the configured SCL channel is
# idle-low with zero transitions" means the analyzer is not seeing SCL on that
# configured channel. That can be a loose tap, a channel-map mismatch, a failed
# analyzer input, or a genuine off-board electrical fault.
#
# It intentionally does NOT write a *_result.json and is not part of
# verify_all.sh or the verification summary: activity counts are a debugging
# aid, not a success criterion. The informational text dump goes to
# evidence/latest/logic_activity.txt.
#
# Usage: scripts/probe_logic_activity.sh [duration_ms]   (default: 6000)
#
# Gate: respects the logic-analyzer safety gate. Enable with one of
#   PICO_LOGIC_ANALYZER=1 / PICO_LOGIC_UART=1 / PICO_LOGIC_I2C=1
# AI agents must not self-enable this (see docs/operations/AGENT_OPERATION.md).
#
# Exit code: 0 = probed or cleanly skipped, 1 = capture failed.

set -u -o pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

DURATION_MS="${1:-6000}"
OUT_TXT="${EVIDENCE_DIR}/logic_activity.txt"

DRIVER="$(cfg_get logic_analyzer.device fx2lafw)"
CONN="$(cfg_get logic_analyzer.conn "")"
SAMPLE_RATE="$(cfg_get logic_analyzer.sample_rate "1 MHz")"
CH_SCL="$(cfg_get logic_analyzer.channels.scl 0)"
CH_SDA="$(cfg_get logic_analyzer.channels.sda 1)"
CH_UART_TX="$(cfg_get logic_analyzer.channels.uart_tx 2)"
CH_UART_RX="$(cfg_get logic_analyzer.channels.uart_rx 3)"

DRIVER_SPEC="${DRIVER}"
if [ -n "${CONN}" ]; then
    DRIVER_SPEC="${DRIVER}:conn=${CONN}"
fi

# Gate: any logic-capture enable flag authorizes this passive probe.
if [ "${PICO_LOGIC_ANALYZER:-0}" != "1" ] \
    && [ "${PICO_LOGIC_UART:-0}" != "1" ] \
    && [ "${PICO_LOGIC_I2C:-0}" != "1" ]; then
    echo "SKIP: logic analyzer not enabled. Set PICO_LOGIC_ANALYZER=1 (or PICO_LOGIC_UART=1 / PICO_LOGIC_I2C=1) to probe channel activity."
    exit 0
fi

if ! command -v sigrok-cli >/dev/null 2>&1; then
    echo "SKIP: sigrok-cli not installed; cannot probe channel activity."
    exit 0
fi

echo "== scripts/probe_logic_activity.sh: probing ${DURATION_MS}ms via ${DRIVER_SPEC} =="
BITS="$(mktemp)"
trap 'rm -f "${BITS}"' EXIT

if ! sigrok-cli \
    --driver "${DRIVER_SPEC}" \
    --config "samplerate=${SAMPLE_RATE}" \
    --time "${DURATION_MS}ms" \
    --channels "D${CH_SCL},D${CH_SDA},D${CH_UART_TX},D${CH_UART_RX}" \
    -O bits > "${BITS}" 2>/dev/null; then
    echo "FAIL: sigrok-cli capture failed (logic analyzer not connected?)"
    exit 1
fi

python3 - "${BITS}" "${CH_SCL}" "${CH_SDA}" "${CH_UART_TX}" "${CH_UART_RX}" <<'PYEOF' | tee "${OUT_TXT}"
import collections, re, sys

path = sys.argv[1]
labels = {
    f"D{sys.argv[2]}": "SCL",
    f"D{sys.argv[3]}": "SDA",
    f"D{sys.argv[4]}": "UART TX",
    f"D{sys.argv[5]}": "UART RX",
}
trans = collections.Counter()
ones = collections.Counter()
total = collections.Counter()
for line in open(path):
    m = re.match(r"^(D\d+):(.*)$", line.strip())
    if not m:
        continue
    ch = m.group(1)
    bits = re.sub(r"[^01]", "", m.group(2))
    prev = None
    for b in bits:
        total[ch] += 1
        if b == "1":
            ones[ch] += 1
        if prev is not None and b != prev:
            trans[ch] += 1
        prev = b

print(f"{'channel':<9}{'signal':<9}{'transitions':>12}{'high%':>8}  state")
for ch in sorted(total, key=lambda c: int(c[1:])):
    t = total[ch] or 1
    state = "ACTIVE" if trans[ch] > 2 else ("IDLE-HIGH" if ones[ch] > t * 0.5 else "IDLE-LOW")
    print(f"{ch:<9}{labels.get(ch, ''):<9}{trans[ch]:>12}{100 * ones[ch] / t:>7.1f}  {state}")
print()
print("Hint: I2C SCL+SDA normally toggle together. If SDA is active but the configured SCL channel is idle-low/0 transitions, the analyzer is not seeing SCL on that channel; check channel mapping, probe input, and the off-board SCL path.")
PYEOF

echo "== probe: done (saved evidence/latest/logic_activity.txt) =="
