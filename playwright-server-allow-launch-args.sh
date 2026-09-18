#!/usr/bin/env bash
# Restores the `args` field of the per-connection launch-options, which Playwright's run-server
# stopped honouring in 1.60.
#
# From 1.60 the server filters client-supplied launch-options through a single `allowUnsafe`
# boolean, dropping args, ignoreDefaultArgs, ignoreAllDefaultArgs, chromiumSandbox and
# executablePath unless it was started with --unsafe. Dropping args disarms every caller that
# relies on them - --no-sandbox, --disable-dev-shm-usage, and
# --disable-blink-features=AutomationControlled, which is what keeps navigator.webdriver false.
# Nothing errors and no warning is logged; the browser simply comes up unhardened.
#
# --unsafe is not the answer, because it ungates all five at once. executablePath is the sharp
# one: the server is unauthenticated, so anyone who can reach the port could point it at an
# arbitrary binary already on the box and pass that binary its arguments. Restoring only `args`
# keeps that shut.
#
# What this deliberately does NOT do is make the server safe to expose. Hostile args alone can
# still do damage (--user-data-dir, --load-extension, --remote-debugging-port, --proxy-server).
# The trust model is unchanged from upstream's: only reachable by callers you trust.
#
# The script fails the build rather than letting the image ship silently unpatched. If a future
# Playwright reformats the line, a best-effort patch would become a no-op and the hardening would
# disappear without a trace - the exact silent failure this exists to prevent.
set -euo pipefail

GATED='args: allowUnsafe ? options.args : void 0,'
OPEN='args: options.args,'

lib="$(npm root -g)/playwright/node_modules/playwright-core/lib"
if [ ! -d "$lib" ]; then
    echo "playwright-core not found under ${lib}" >&2
    exit 1
fi

file="$(grep -rlF "$GATED" "$lib" || true)"

if [ -z "$file" ]; then
    # No gate found. Either this is a pre-1.60 server, which passes args through already and
    # needs nothing done, or Playwright has changed shape and the assumption no longer holds.
    # Only the first is acceptable.
    if grep -rqF "$OPEN" "$lib"; then
        echo "no launch-options gate present - args already pass through unfiltered"
        exit 0
    fi
    echo "found neither the launch-options args gate nor an ungated equivalent." >&2
    echo "Playwright's filterLaunchOptions has changed shape; review it before bumping." >&2
    exit 1
fi

matches="$(printf '%s\n' "$file" | wc -l | tr -d ' ')"
if [ "$matches" != "1" ]; then
    echo "expected the gate in exactly one file, found ${matches}:" >&2
    printf '%s\n' "$file" >&2
    exit 1
fi

occurrences="$(grep -cF "$GATED" "$file")"
if [ "$occurrences" != "1" ]; then
    echo "expected 1 occurrence of the gate in ${file}, found ${occurrences}" >&2
    exit 1
fi

node -e '
const fs = require("fs");
const [file, gated, open] = process.argv.slice(1);
const before = fs.readFileSync(file, "utf8");
const after = before.replace(gated, open);
if (after === before) {
    console.error("replacement made no change to " + file);
    process.exit(1);
}
fs.writeFileSync(file, after);
' "$file" "$GATED" "$OPEN"

if grep -qF "$GATED" "$file"; then
    echo "the gate is still present in ${file} after patching" >&2
    exit 1
fi

echo "launch-options args restored in ${file}"
