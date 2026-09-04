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

### Step 6: Configure connector environment variables

Deploy-time env vars do not reach `stdio` MCP connectors. After the first deploy,
open the Console and set the `everos` connector env to the **literal** values, or
its calls fail with `401`:

- `EVERMEMOS_API_KEY` → the literal `EVEROS_API_KEY` value
- `EVERMEMOS_USER_ID` → `omp-user`
- `EVERMEMOS_BASE_URL` → `https://api.evermind.ai`

Full rationale and the CLI equivalent are in
[MCP Connector Environment Variables](#mcp-connector-environment-variables).

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

**Consequence:** a `stdio` connector that authenticates with an API key needs the
**literal key value in the connector's own `env` block**. Compose-level variables
are necessary for the daemon and for `http`/`sse` connectors, but not sufficient
for `stdio` ones.

The `everos` (EverMeMOS memory) connector is `stdio`, so its env block must be:

| Connector env key    | Value                                       |
| -------------------- | ------------------------------------------- |
| `EVERMEMOS_API_KEY`  | the literal key copied from `EVEROS_API_KEY` |
| `EVERMEMOS_USER_ID`  | `omp-user`                                  |
| `EVERMEMOS_BASE_URL` | `https://api.evermind.ai`                   |

Set these in the Console under **Waker → Connectors → everos → Environment**, or
with the CLI (`mcp update` raises a config proposal you must approve in Console):

```bash
qoderwake mcp update \
  --waker-id <wakerId> \
  --mcp-id <everosMcpId> \
  --env '{"EVERMEMOS_API_KEY":"<literal-key>","EVERMEMOS_USER_ID":"omp-user","EVERMEMOS_BASE_URL":"https://api.evermind.ai"}'
```

Keep `EVEROS_API_KEY` in Coolify too: it is the single place you store the key,
and the connector value should be copied from it.

> **Trade-off:** because the literal key lives in the connector config, it is
> persisted inside the `qoderwake_data` volume (`.mcp.json` plus the daemon
> connector store), not only in Coolify. Rotating the key means updating **both**.
> Treat that volume as secret-bearing: restrict host access and avoid committing
> or shipping backups of it.

## Architecture

```
┌──────────────────────────────────────────┐
│              Coolify Server              │
│                                          │
│  ┌────────────────────────────────────┐  │
│  │        Docker Container            │  │
│  │                                    │  │
│  │   Ubuntu 22.04                     │  │
│  │   └── QoderWake Service            │  │
│  │       ├── Web Console (:19820)     │  │
│  │       ├── Waker Management         │  │
│  │       └── Task Execution           │  │
│  │                                    │  │
│  │   Volume: qoderwake_data           │  │
│  │   └── ~/.qoderwake (persisted)     │  │
│  └────────────────────────────────────┘  │
│                                          │
│  Coolify Reverse Proxy (Traefik/Caddy)   │
│  └── your-domain.com → :19820           │
└──────────────────────────────────────────┘
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

**Fix:** put the literal key (plus `EVERMEMOS_USER_ID` and `EVERMEMOS_BASE_URL`) in
the connector env as shown above.

**Two gotchas after fixing:**

- Editing `.mcp.json` by hand is only a stopgap. The connector store is the source
  of truth and is re-materialised over that file, so the placeholder comes back on
  the next sync. Always fix it with `qoderwake mcp update` / the Console.
- A `stdio` connector process is not re-spawned inside a live session. Start a new
  session (or restart the daemon) before re-testing, otherwise you still hit the old
  process holding the old key.

## Updating QoderWake

To update to the latest QoderWake version:

1. In Coolify, trigger a **Rebuild** of the service
2. The Dockerfile will re-run the install script and pull the latest version
3. Your data persists through the `qoderwake_data` volume

## License

This deployment configuration is provided as-is. QoderWake is a product of [Qoder / Alibaba Cloud](https://qoder.com) — refer to their terms for licensing.
