# Cloud Storage Setup — Dropbox & Google Drive via rclone

This document explains how to configure Dropbox and/or Google Drive cloud upload for the **Process Videos** workflow.

## Overview

When you trigger the workflow manually (`workflow_dispatch`) you can choose:

| Input | Description |
|-------|-------------|
| `upload_mirror` | `none` · `dropbox` · `gdrive` · `both` |
| `cloud_folder` | Destination folder name in the cloud (default: `ProcessedVideos`) |

Processed `.mp4` files are uploaded to the selected cloud destination **before** zip packaging. The GitHub Release with zip parts is still created regardless of the cloud upload option.

---

## Required GitHub Secrets

| Secret name | Used for |
|-------------|----------|
| `RCLONE_DROPBOX_TOKEN` | Dropbox OAuth2 token (JSON) |
| `RCLONE_GDRIVE_TOKEN` | Google Drive OAuth2 token (JSON) |

You only need to add the secret(s) for the service(s) you intend to use.

---

## Step 1 — Install rclone locally

```bash
# Linux / macOS
curl https://rclone.org/install.sh | sudo bash

# Windows (PowerShell)
winget install Rclone.Rclone
```

Verify: `rclone --version`

---

## Step 2 — Authorize Dropbox

Run the interactive authorization on your local machine:

```bash
rclone config
```

Follow the prompts:

1. `n` → New remote
2. Name: `dropbox`
3. Storage type: choose **Dropbox** (type the number shown)
4. Leave `client_id` and `client_secret` blank (use rclone defaults)
5. `n` → No advanced config
6. `y` → Use auto config (opens browser for OAuth)
7. Log in to Dropbox and click **Allow**
8. `y` → Confirm

After authorization, extract the token JSON:

```bash
rclone config show dropbox | grep "^token"
# Output example:
# token = {"access_token":"sl.xxx...","token_type":"bearer","refresh_token":"xxx","expiry":"2025-..."}
```

Copy the **value after `token = `** (the JSON string). This is your `RCLONE_DROPBOX_TOKEN` secret value.

---

## Step 3 — Authorize Google Drive

```bash
rclone config
```

Follow the prompts:

1. `n` → New remote
2. Name: `gdrive`
3. Storage type: choose **Google Drive** (type the number shown)
4. Leave `client_id` and `client_secret` blank (use rclone defaults)
5. Scope: choose **1** — Full access to all files
6. Leave `root_folder_id` and `service_account_file` blank
7. `n` → No advanced config
8. `y` → Use auto config (opens browser for OAuth)
9. Log in to Google and click **Allow**
10. When asked if it's a Shared Drive (team drive), answer `n` (unless you are using a Shared Drive)

After authorization, extract the token JSON:

```bash
rclone config show gdrive | grep "^token"
# Output example:
# token = {"access_token":"ya29.xxx","token_type":"Bearer","refresh_token":"1//xxx","expiry":"2025-..."}
```

Copy the **value after `token = `** (the JSON string). This is your `RCLONE_GDRIVE_TOKEN` secret value.

---

## Step 4 — Add secrets to GitHub

1. Open your repository on GitHub.
2. Go to **Settings → Secrets and variables → Actions**.
3. Click **New repository secret**.
4. Add each secret:

| Name | Value |
|------|-------|
| `RCLONE_DROPBOX_TOKEN` | The JSON string from Step 2 |
| `RCLONE_GDRIVE_TOKEN` | The JSON string from Step 3 |

> **Security note:** Never commit the token JSON to the repository. Keep it only in GitHub Secrets.

---

## Step 5 — Run the workflow

1. Go to **Actions → Process Videos → Run workflow**.
2. Set `upload_mirror` to `dropbox`, `gdrive`, or `both`.
3. Optionally set `cloud_folder` (default: `ProcessedVideos`).
4. Click **Run workflow**.

Processed `.mp4` files will be uploaded to:

- **Dropbox:** `Dropbox/ProcessedVideos/`
- **Google Drive:** `My Drive/ProcessedVideos/`

---

## Token refresh

rclone tokens include a `refresh_token` and are refreshed automatically during upload. If a token expires permanently, repeat Steps 2–4 to generate a new one and update the GitHub Secret.

---

## Troubleshooting

| Error | Fix |
|-------|-----|
| `RCLONE_DROPBOX_TOKEN secret is not set` | Add the secret in GitHub Settings (Step 4) |
| `RCLONE_GDRIVE_TOKEN secret is not set` | Add the secret in GitHub Settings (Step 4) |
| `Failed to copy: …401 Unauthorized` | Token expired — re-authorize and update the secret |
| `Failed to copy: …quota` | Google Drive storage quota exceeded |
| Upload is slow | Reduce `--transfers` in the workflow (default: 8) |
