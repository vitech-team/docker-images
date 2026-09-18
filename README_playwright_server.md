# playwright-server

A [Playwright](https://playwright.dev) browser server that runs browsers on a virtual display
and exports that display over VNC, so a remote automation session can be watched while it runs.

Built on the official Playwright image, with the Playwright CLI pinned to the image tag.

| Port | Purpose |
|------|---------|
| 4444 | Playwright server — what clients connect to |
| 7900 | noVNC over http — watch the session in a browser |
| 5900 | raw VNC — for a native VNC client |

Port numbers match the Selenium standalone images, so tooling built around those carries over.

## Usage

```sh
docker run -d --name playwright-server \
    --shm-size 1g \
    -p 4444:4444 -p 7900:7900 \
    vitechteam/playwright-server:1.63.0-1
```

Connect a Playwright client to `ws://localhost:4444/pw`, and open
<http://localhost:7900/vnc.html> (password `secret`) to watch.

`--shm-size 1g` is not optional: Chromium crashes on Docker's default 64MB of shared memory.

Per-connection browser settings travel in the `launch-options` query parameter, so one server
can serve callers wanting different browsers:

```
ws://localhost:4444/pw?launch-options={"headless":false,"channel":"chromium","args":["--no-sandbox"]}
```

Each connection gets its own browser process, so one crashing browser does not take the others
with it. `PLAYWRIGHT_MAX_CLIENTS` bounds how many are served at once.

### Browser arguments

`args` in `launch-options` reaches the browser, which upstream's own `run-server` stops doing
from Playwright 1.60: it drops `args` — along with `ignoreDefaultArgs`, `ignoreAllDefaultArgs`,
`chromiumSandbox` and `executablePath` — unless started with `--unsafe`. Silently, so a caller
passing `--no-sandbox` or `--disable-blink-features=AutomationControlled` gets a browser that
ignored both and says nothing about it.

This image restores `args` alone. It does **not** run with `--unsafe`, so `executablePath`
stays gated — on an unauthenticated server that one amounts to running an arbitrary binary on
the host, which is a much larger thing to hand out than a list of Chromium flags.

That is not a claim the server is safe to expose; see [Security](#security). Hostile `args` can
still do real damage on their own.

## Tags

| Tag | Moves? | Use it for |
|---|---|---|
| `1.63.0-1` | never | deployments — an exact, reproducible build |
| `1.63.0` | yes, to the newest revision of that Playwright version | development, and anywhere a rebuild should be picked up |

The first number is the Playwright version the server runs. **It must match the Playwright
client library connecting to it**; a mismatch is refused on connect with
`428 Precondition Required`, naming neither version.

The second number is the image revision. It exists because the image sometimes needs rebuilding
without Playwright having moved — a base image update, a fix to the entrypoint, a new package.
Without it there would be no way to say "same Playwright, newer image" except by mutating a
published tag.

Moving the bare `1.63.0` tag is safe for that reason: the part that has to match your client is
still fixed, and only the image build underneath it changes.

**There is deliberately no `latest`.** It would silently change the Playwright version, which is
the one thing that cannot change without breaking the client it talks to.

Published for `linux/amd64` and `linux/arm64`.

## Configuration

| Variable | Default | Purpose |
|---|---|---|
| `PLAYWRIGHT_PORT` | `4444` | Port the server listens on |
| `PLAYWRIGHT_PATH` | `/pw` | Endpoint path — part of the connect URL |
| `PLAYWRIGHT_MAX_CLIENTS` | `10` | Concurrent clients served at once |
| `SCREEN_GEOMETRY` | `1440x900x24` | Virtual display size |
| `START_VNC` | `true` | Set `false` to run without the VNC layer |
| `VNC_PASSWORD` | `secret` | VNC password — **override this** |

## Headless or headed

Headless is the client's choice, not the server's: pass `"headless": false` in `launch-options`
and the session becomes visible over VNC. The image always starts the virtual display so that
choice stays open.

Two things worth knowing when choosing:

- a headless browser renders nothing, so there is nothing to watch over VNC
- Playwright's `headless: true` selects a stripped `headless_shell` binary that reports no
  plugins and no `window.chrome`; passing `"channel": "chromium"` selects the full browser
  instead, and headed additionally drops the `HeadlessChrome` token from the user agent

## Version lockstep

The image tag is the Playwright version, and the client library must match it. Playwright
checks the protocol version on connect and rejects a mismatch with `428 Precondition Required`,
naming neither version — so a drifted pair is hard to diagnose from the error alone.

The image pins the server for this reason. A bare `npx playwright run-server` would resolve
against the npm registry and silently run the newest release rather than the one the image was
built for.

## Security

**The server is unauthenticated.** Anyone who can reach port 4444 can drive a browser from
wherever the container runs, including at any network the container can see. Do not expose it
to the internet. The same applies to the VNC ports; set `START_VNC=false` where they are not
needed, and always override `VNC_PASSWORD`.

**Callers choose the browser's arguments.** `args` from `launch-options` is passed through (see
[Browser arguments](#browser-arguments)), so a caller can set flags that weaken the browser or
reach the filesystem — `--user-data-dir`, `--load-extension`, `--remote-debugging-port`,
`--proxy-server`. `executablePath` is gated and cannot be set. Treat reachability of port 4444
as the security boundary, as upstream does.

**Connections are long-lived WebSockets.** A client holds one socket open for the duration of
its work, so an idle timeout on a proxy or load balancer in front of the server will kill
sessions in progress. This differs from Selenium's short HTTP request-response calls, which
survive an idle timeout untouched.

## Licence

Apache-2.0, as the rest of this repository.
