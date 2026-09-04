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

| Variable                      | Required | Description                                |
| ----------------------------- | -------- | ------------------------------------------ |
| `QODER_PERSONAL_ACCESS_TOKEN` | ✅ Yes   | Your Qoder PAT for headless authentication |
| `QODERWAKE_PORT`              | No       | Host port (default: `19820`)               |

### Step 4: Configure domain (optional)

In Coolify, you can assign a custom domain and Coolify will auto-provision an SSL certificate via Let's Encrypt. Set the proxy to forward to port `19820`.

### Step 5: Deploy

Click **Deploy** in Coolify. The build will:

1. Build the Docker image (installs QoderWake via the official installer)
2. Start the container
3. Authenticate using your PAT
4. Start the QoderWake service on `0.0.0.0:19820`

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

### Viewing Logs

In Coolify, go to your service → **Logs** tab to see real-time container output.

## Updating QoderWake

To update to the latest QoderWake version:

1. In Coolify, trigger a **Rebuild** of the service
2. The Dockerfile will re-run the install script and pull the latest version
3. Your data persists through the `qoderwake_data` volume

## License

This deployment configuration is provided as-is. QoderWake is a product of [Qoder / Alibaba Cloud](https://qoder.com) — refer to their terms for licensing.
