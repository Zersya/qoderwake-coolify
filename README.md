# QoderWake — Coolify Deployment

Deploy [QoderWake](https://qoder.com/qoderwake) (AI Digital Employee Platform) on your own server using [Coolify](https://coolify.io).

## What is QoderWake?

QoderWake is an agentic AI platform that creates **digital employees called Wakers** to handle ongoing work — software engineering, operations, data analysis, and more. This repo packages it for self-hosted deployment via Coolify.

## Prerequisites

- A running [Coolify](https://coolify.io) instance (v4+)
- A server with **4 GB+ RAM** and **500 MB+ free disk**
- A [Qoder account](https://qoder.com) with a **Personal Access Token (PAT)**

### Generating a Personal Access Token

1. Go to [qoder.com](https://qoder.com) and sign in
2. Navigate to **Account Settings → Personal Access Tokens**
3. Create a new token and copy it — you'll need it for the `QODER_PERSONAL_ACCESS_TOKEN` environment variable

## Deploy on Coolify

### Step 1: Push this repo to GitHub

```bash
# If you haven't already
git remote add origin https://github.com/<your-username>/qoderwake-coolify.git
git push -u origin main
```

### Step 2: Create the service in Coolify

1. Open your Coolify dashboard
2. Go to **Projects → Add New Resource → Docker Compose**
3. Connect your GitHub repository (`qoderwake-coolify`)
4. Coolify will auto-detect the `docker-compose.yml`

### Step 3: Configure environment variables

In Coolify's service settings, add:

| Variable                      | Required | Description                                          |
| ----------------------------- | -------- | ---------------------------------------------------- |
| `QODER_PERSONAL_ACCESS_TOKEN` | ✅ Yes   | Your Qoder PAT for headless authentication           |
| `QODERWAKE_PORT`              | No       | Host port (default: `19820`)                         |
| `EVEROS_API_KEY`              | If using EverMeMOS | EverMeMOS / EverOS API key, see below        |

### Step 4: Configure domain (optional)

In Coolify, you can assign a custom domain and Coolify will auto-provision an SSL certificate via Let's Encrypt. Set the proxy to forward to port `19820`.

### Step 5: Deploy

Click **Deploy** in Coolify. The build will:

1. Build the Docker image (installs QoderWake via the official installer)
2. Start the container
3. Authenticate using your PAT
4. Start the QoderWake service on `0.0.0.0:19820`

### Step 6: Point the `everos` connector at the launcher

Deploy-time env vars do not reach `stdio` MCP connectors, and the Console rejects
connector env keys that look sensitive (`EVERMEMOS_API_KEY` included). After the
first deploy, open the Console and change the `everos` connector **Command** to
`/home/qoderwake/.qoderwake/bin/evermemos-launch.sh` with **empty Arguments and
empty Env** — the launcher injects the credentials written by `entrypoint.sh`
from `EVEROS_API_KEY` at container start. Skip this and EverMeMOS calls fail
with `401`.

Full rationale is in [MCP Connector Environment Variables](#mcp-connector-environment-variables).

### Step 7: Set up the Browser Connector (Chrome DevTools MCP)

The browser connector lets QoderWake control your **local** Chrome browser via
the Chrome DevTools Protocol (CDP). This is separate from the Chrome installed
inside the container (which is for headless/Puppeteer-based MCP tools).

The connector works through a **Chrome extension** that you install in your
local browser. The extension connects to the QoderWake container via WebSocket
on port `16789`.

#### 7a. Enable the browser connector

The `entrypoint.sh` script attempts to auto-enable the browser connector on
startup. If it doesn't, enable it manually:

1. Open the QoderWake Console
2. Go to **Settings → Connectors**
3. Find **"Connect to Browser"** and toggle it **ON**

#### 7b. Install the Chrome extension

The extension is bundled in the Docker image. Run the setup script to package
it, then copy it to your local machine:

```bash
# Run the setup script inside the container
docker exec qoderwake bash /home/qoderwake/.qoderwake/bin/setup-browser-extension.sh

# Copy the extension to your local machine
docker cp qoderwake:/home/qoderwake/.qoderwake/browser-extension-download/chrome-extension ./chrome-extension
```

Then load it in Chrome:

1. Open `chrome://extensions/` in your Chrome browser
2. Enable **Developer mode** (toggle in the top-right corner)
3. Click **"Load unpacked"**
4. Select the `chrome-extension` directory you copied

#### 7c. Connect the extension to QoderWake

Open the extension popup (click the extension icon in Chrome) and configure
the WebSocket URL:

```
ws://<your-server-ip-or-domain>:16789/extension/v2
```

- If you have a domain: `ws://your-domain.com:16789/extension/v2`
- Without a domain: `ws://<server-ip>:16789/extension/v2`

> **Note:** if you're using HTTPS for the Console, the extension may need a
> `wss://` URL. Ensure your reverse proxy forwards WebSocket connections on
> port 16789 as well.

Once connected, the browser connector status in the Console should show
**"Connected"** and QoderWake will be able to control your browser.

## Access the Web Console

After deployment, access QoderWake at:

- **With domain**: `https://your-domain.com`
- **Without domain**: `http://<server-ip>:19820`

On first visit, you'll need to complete the Qoder login flow in your browser.

## Environment Variables

| Variable                      | Default   | Description                                    |
| ----------------------------- | --------- | ---------------------------------------------- |
| `QODER_PERSONAL_ACCESS_TOKEN` | —         | Qoder PAT for authentication                   |
| `QODER_TOKEN_FILE`            | —         | Alternative: path to a file containing the PAT |
| `QODERWAKE_HOST`              | `0.0.0.0` | Bind address inside the container              |
| `QODERWAKE_PORT`              | `19820`   | Port mapping on the host                       |
| `EVEROS_API_KEY`              | —         | EverMeMOS / EverOS API key (see below)         |

## MCP Connector Environment Variables

Setting an environment variable in `docker-compose.yml` makes it visible to the
**QoderWake daemon**, but it does **not** automatically reach an MCP connector.
Two QoderWake behaviours are responsible, and they bite at the same time:

1. **`${env:VAR}` is not a secret interpolator.** Connector `env` values are written
   verbatim into the materialised worker file
   `~/.qoderwake/data/workers/<wakerId>/.qoder-plugin/.mcp.json`. The only
   placeholders QoderWake expands are `HOME`, `USERPROFILE`, `QODER_CONFIG_DIR`,
   `QODER_CLI_HOME` and `GEMINI_CLI_HOME`, and only when followed by a path
   separator. A value such as `${env:EVEROS_API_KEY}` is **not** expanded — the
   connector receives that exact string as its API key.
2. **stdio connectors get an allowlisted environment.** `stdio` MCP servers are
   launched with only `HOME`, `LOGNAME`, `PATH`, `SHELL`, `TERM` and `USER`
   inherited from the daemon, plus whatever the connector's own `env` block sets.
   Container-level variables such as `EVERMEMOS_API_KEY` are therefore never seen
   by a `stdio` connector.

**Consequence:** you cannot hand a `stdio` connector its secret through the
environment, and there is an extra UI constraint:

3. **The Console refuses sensitive env keys.** Trying to add a connector env
   variable whose name looks sensitive (`token`, `secret`, `password`, `auth`,
   `credential`, …) is rejected with "MCP environment variables cannot include
   sensitive … keys". `EVERMEMOS_API_KEY` is blocked on that rule.
4. **The env name is not negotiable.** `evermemos-mcp` hardcodes
   `os.getenv("EVERMEMOS_API_KEY")` (`config.py`), so renaming the variable to
   dodge the UI rule would silently disable authentication.

**Supported pattern — launcher script with a credentials file.** This repo ships
`evermemos-launch.sh`: the connector's **Command** points at it (empty args,
empty env), and it injects the credentials before exec'ing the real server.
`entrypoint.sh` writes those credentials at container start from the Coolify
env vars into `~/.qoderwake/.everos/credentials.env` (mode `0600`, inside the
`qoderwake_data` volume), so:

- no secret ever lives in the connector config / `.mcp.json` / Console;
- key rotation = update `EVEROS_API_KEY` in Coolify + redeploy (the file is
  rewritten on every start);
- it survives QoderWake re-materialisation, because the connector config never
  contains the key in the first place.

One-time per-waker Console change (no sensitive values involved): open the
`everos` connector and replace its launch configuration with:

| Field     | Value                                                              |
| --------- | ------------------------------------------------------------------ |
| Command   | `/home/qoderwake/.qoderwake/bin/evermemos-launch.sh`               |
| Arguments | *(empty)*                                                          |
| Env       | *(empty)* — credentials are injected from the volume file          |

> **Fallback:** if you are not using this repo's image (so the launcher file is
> missing), any equivalent wrapper script with the same behaviour works — the
> point is that the secret travels via a file, never via the connector env.

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                     Coolify Server                      │
│                                                         │
│  ┌──────────────────────────────────────────────────┐   │
│  │              Docker Container                    │   │
│  │                                                  │   │
│  │   Ubuntu 22.04                                   │   │
│  │   └── QoderWake Service                          │   │
│  │       ├── Web Console (:19820)                   │   │
│  │       ├── Browser Relay (:16789) ◄── WebSocket   │   │
│  │       ├── Waker Management                       │   │
│  │       └── Task Execution                         │   │
│  │                                                  │   │
│  │   Volume: qoderwake_data                         │   │
│  │   └── ~/.qoderwake (persisted)                   │   │
│  └──────────────────────────────────────────────────┘   │
│                                                         │
│  Coolify Reverse Proxy (Traefik/Caddy)                  │
│  └── your-domain.com → :19820 / :16789                 │
└─────────────────────────────────────────────────────────┘
         ▲
         │ WebSocket (ws://...:16789/extension/v2)
         │
┌────────┴──────────────────────────────┐
│         Your Local Machine            │
│  ┌─────────────────────────────────┐  │
│  │  Chrome Browser                 │  │
│  │  └── QoderWake Extension        │  │
│  │      (loaded as unpacked ext)   │  │
│  └─────────────────────────────────┘  │
└───────────────────────────────────────┘
```

## Data Persistence

The `qoderwake_data` Docker volume persists:

- Authentication state
- Waker configurations
- Knowledge bases
- Projects and workspace data
- Memory and skills

Your data survives container restarts and redeployments.

## Troubleshooting

| Issue                            | Solution                                                                   |
| -------------------------------- | -------------------------------------------------------------------------- |
| Container fails to start         | Check logs in Coolify → ensure PAT is valid                                |
| Can't access Web Console         | Verify port `19820` is exposed and firewall allows it                      |
| Authentication fails             | Regenerate your PAT and update the env variable in Coolify                 |
| Service keeps restarting         | Check container logs for specific errors; ensure 4GB+ RAM available        |
| "qoderwake not found"            | The install script may have failed — check build logs                      |
| EverMeMOS MCP returns **401**    | Connector `env` holds `${env:EVEROS_API_KEY}` instead of the literal key — see below |
| Browser connector not detecting browser | Enable connector in Console, install Chrome extension, verify port 16789 is reachable — see below |
| chrome-devtools-mcp fails to start | Node.js/npx not found — ensure you're using the latest image with Node.js 20 LTS bundled |

### Viewing Logs

In Coolify, go to your service → **Logs** tab to see real-time container output.

### EverMeMOS / `everos` connector returns 401

**Symptom:** every `everos` tool call fails with `401 Unauthorized`, even though
`EVEROS_API_KEY` is set in Coolify and the container is healthy.

**Root cause:** the connector's `EVERMEMOS_API_KEY` is the literal string
`${env:EVEROS_API_KEY}`. QoderWake does not expand it (see
[MCP Connector Environment Variables](#mcp-connector-environment-variables)), so
that placeholder is sent to EverMind as the bearer token.

**Diagnose** — confirm the key itself is valid, then read what the connector is
actually sending. A `404` proves authentication passed and only the path is wrong;
a `401` proves the token is bad:

```bash
# 1. Is the key in the container env valid? Expect 404 (auth OK, path wrong), not 401.
curl -s -o /dev/null -w '%{http_code}\n' \
  -H "Authorization: Bearer $EVEROS_API_KEY" \
  https://api.evermind.ai/api/v1/groups

# 2. What did QoderWake materialise for this waker? A literal "${env:...}" here is the bug.
python3 -c "import json,os;print(json.load(open(os.path.expanduser(
  '~/.qoderwake/data/workers/<wakerId>/.qoder-plugin/.mcp.json'
)))['mcpServers']['everos']['env'])"

# 3. Same question against the durable source of truth (the connector store).
#    Note: `mcp get` has no --json flag and its output is prefixed with "[qoderwake]".
qoderwake mcp get --waker-id <wakerId> --mcp-id <everosMcpId> \
  | python3 -c "import sys,json,re;print(json.loads(re.sub(r'^\[qoderwake\]\s*','',sys.stdin.read()))['env'])"
```

**Fix (permanent):**

1. Redeploy so `entrypoint.sh` writes `~/.qoderwake/.everos/credentials.env`
   (mode `0600`) from the Coolify env vars.
2. In the Console, change the `everos` connector **Command** to
   `/home/qoderwake/.qoderwake/bin/evermemos-launch.sh` (empty Arguments and Env).
3. Start a new session and call an `everos` tool again.

The UI rule against sensitive env keys means the old "literal key in the
connector env" workaround cannot be entered from the Console at all — the
launcher exists precisely to move the secret to a file.

**Gotchas:**

- Editing `.mcp.json` by hand is only a stopgap. The connector store is the
  source of truth and is re-materialised over that file. A literal key there
  also means the secret is persisted in the connector config, which the launcher
  pattern avoids entirely.
- A `stdio` connector process is not re-spawned inside a live session. Start a
  new session (or restart the daemon) before re-testing, otherwise you still hit
  the old process holding the old key.
- If the connector still sends `${env:...}`, its env block was left in place —
  clear it in the Console (empty env) so the launcher is the only source.

### Browser connector not detecting browser

**Symptom:** the "Connect to Browser" connector shows `not_connected` and
`v2ExtensionConnected: false`, even though the container is healthy.

**Root cause:** the browser connector does not use the Chrome installed inside
the Docker container. It works through a Chrome extension running in your
**local** browser that connects to the container via WebSocket on port 16789.
If the extension is not installed or cannot reach the relay, no browser is
detected.

**Diagnose:**

```bash
# 1. Is the browser relay running inside the container?
docker exec qoderwake curl -s http://127.0.0.1:16789/extension/status
# Expected: {"connected":false,"enabled":true,"version":"v2"}
# If "enabled":false → the connector is not enabled

# 2. Is port 16789 reachable from your local machine?
curl -s http://<your-server-ip>:16789/extension/status
# If connection refused → port is not exposed or firewall is blocking it

# 3. Is the Chrome extension installed and configured?
# Open chrome://extensions/ and check if the QoderWake extension is loaded.
```

**Fix:**

1. Ensure port `16789` is exposed in `docker-compose.yml` (this repo already
   includes it).
2. Enable the browser connector in the Console (Settings → Connectors →
   "Connect to Browser" → toggle ON). The `entrypoint.sh` also tries to
   auto-enable it on startup.
3. Install the Chrome extension in your local browser (see
   [Step 7](#step-7-set-up-the-browser-connector-chrome-devtools-mcp)).
4. Configure the extension with the WebSocket URL:
   `ws://<your-server-ip-or-domain>:16789/extension/v2`

**Gotchas:**

- The Chrome installed in the Docker container (`google-chrome-stable`) is for
  headless/Puppeteer-based MCP tools (e.g., `@anthropic/chrome-devtools-mcp`).
  It is **not** what the browser connector uses.
- If you use HTTPS for the Console, the extension may need a `wss://` URL.
  Configure your reverse proxy (Traefik/Caddy) to forward WebSocket
  connections on port 16789 with TLS termination.
- The browser extension connects from your **local machine**, not from inside
  the container. Make sure your firewall allows inbound connections on port
  16789.

## Updating QoderWake

To update to the latest QoderWake version:

1. In Coolify, trigger a **Rebuild** of the service
2. The Dockerfile will re-run the install script and pull the latest version
3. Your data persists through the `qoderwake_data` volume

## License

This deployment configuration is provided as-is. QoderWake is a product of [Qoder / Alibaba Cloud](https://qoder.com) — refer to their terms for licensing.
