#!/usr/bin/env bash
set -euo pipefail

# Defaulted here rather than in the Dockerfile so no password ships baked into the image metadata.
VNC_PASSWORD="${VNC_PASSWORD:-secret}"

# Browsers run headed so the session is visible over VNC and so the page is served by the full
# chromium build rather than the headless shell, which reports no plugins and no window.chrome.
# Headed requires an X display, so Xvfb always starts even when VNC is switched off.
rm -f /tmp/.X*-lock /tmp/.X11-unix/X* 2>/dev/null || true

Xvfb "${DISPLAY}" -screen 0 "${SCREEN_GEOMETRY}" -ac +extension RANDR -noreset &

for _ in $(seq 1 30); do
    if xdpyinfo -display "${DISPLAY}" >/dev/null 2>&1; then break; fi
    sleep 0.5
done
if ! xdpyinfo -display "${DISPLAY}" >/dev/null 2>&1; then
    echo "Xvfb failed to start on ${DISPLAY}" >&2
    exit 1
fi

fluxbox -display "${DISPLAY}" >/dev/null 2>&1 &

if [ "${START_VNC}" = "true" ]; then
    # -usepw reads the password file written below; without it the display is exposed unauthenticated.
    mkdir -p "${HOME}/.vnc"
    x11vnc -storepasswd "${VNC_PASSWORD}" "${HOME}/.vnc/passwd" >/dev/null 2>&1
    x11vnc -usepw -forever -shared -rfbport "${VNC_PORT}" -display "${DISPLAY}" >/dev/null 2>&1 &
    websockify --web /usr/share/novnc "${NO_VNC_PORT}" "localhost:${VNC_PORT}" >/dev/null 2>&1 &
    echo "[playwright-server] noVNC on http://localhost:${NO_VNC_PORT}/vnc.html (password: ${VNC_PASSWORD})"
else
    echo "[playwright-server] VNC disabled (START_VNC=${START_VNC})"
fi

echo "[playwright-server] starting on ws://0.0.0.0:${PLAYWRIGHT_PORT}${PLAYWRIGHT_PATH}"

# exec so the server is PID 1 and receives SIGTERM directly: a stop that killed the wrapper
# instead would leave browsers running until the container was force-killed.
exec playwright run-server \
    --port "${PLAYWRIGHT_PORT}" \
    --host 0.0.0.0 \
    --path "${PLAYWRIGHT_PATH}" \
    --max-clients "${PLAYWRIGHT_MAX_CLIENTS}"
