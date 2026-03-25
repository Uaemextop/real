# Telegram Setup — Upload Processed Videos to a Telegram Channel

This document explains how to configure Telegram uploads for the **Process Videos** workflow.

## Overview

When you trigger the workflow manually (`workflow_dispatch`) you can choose:

| Input | Description |
|-------|-------------|
| `upload_telegram` | `yes` or `no` (default: `no`) |

Processed `.mp4` files are uploaded to the specified Telegram channel **after** encoding
and cloud upload (if enabled), and **before** zip packaging.

> **Note:** The Telegram Bot API has a **50 MB per file** limit. Videos larger than
> 50 MB are automatically skipped with a warning in the workflow logs.

---

## Required GitHub Secrets

| Secret name | Used for |
|-------------|----------|
| `TELEGRAM_BOT_TOKEN` | Bot authentication token from @BotFather |
| `TELEGRAM_CHAT_ID` | Numeric ID of the target channel or group |

Both secrets are required when `upload_telegram` is set to `yes`.

---

## Step 1 — Create a Telegram Bot

1. Open Telegram and search for **@BotFather**.
2. Start a conversation and send `/newbot`.
3. Follow the prompts:
   - **Bot name**: Choose a display name (e.g. `Video Uploader`).
   - **Bot username**: Choose a unique username ending in `bot` (e.g. `my_video_uploader_bot`).
4. @BotFather will reply with a message containing your **bot token**:

   ```
   Use this token to access the HTTP API:
   123456789:ABCdefGhIjKlMnOpQrStUvWxYz
   ```

5. Copy the token (the full string including the colon). This is your `TELEGRAM_BOT_TOKEN`.

> **Security note:** Never share the bot token publicly. Anyone with the token can
> control the bot.

---

## Step 2 — Create a Telegram Channel (or use an existing one)

1. In Telegram, tap the **New Channel** button (or use an existing channel).
2. Give the channel a name and optionally a username (e.g. `@my_videos_channel`).
3. Set the channel to **Public** or **Private** depending on your preference.

---

## Step 3 — Add the Bot to the Channel as Admin

1. Open your Telegram channel.
2. Go to **Channel Settings → Administrators → Add Administrator**.
3. Search for your bot by its username (e.g. `@my_video_uploader_bot`).
4. Grant the bot the **Post Messages** permission (required for sending videos).
5. Save the changes.

---

## Step 4 — Get the Channel Chat ID

### Option A: Public channel with a username

If your channel has a public username like `@my_videos_channel`, the chat ID is simply
the username prefixed with `@`:

```
@my_videos_channel
```

Use this as your `TELEGRAM_CHAT_ID` secret value.

### Option B: Private channel (or prefer numeric ID)

1. Send any message to your channel.
2. Open a browser and go to:

   ```
   https://api.telegram.org/bot<YOUR_BOT_TOKEN>/getUpdates
   ```

   Replace `<YOUR_BOT_TOKEN>` with the token from Step 1.

3. Look for the `"chat"` object in the JSON response. The `"id"` field is your
   numeric chat ID. For channels it is typically a **negative number** (e.g. `-1001234567890`).

   ```json
   {
     "ok": true,
     "result": [
       {
         "message": {
           "chat": {
             "id": -1001234567890,
             "title": "My Videos",
             "type": "channel"
           }
         }
       }
     ]
   }
   ```

4. Copy the numeric ID (including the minus sign). This is your `TELEGRAM_CHAT_ID`.

> **Tip:** If `getUpdates` returns an empty `result`, forward a channel message to the
> bot first, then refresh the URL.

### Option C: Using @userinfobot

1. Forward any message from your channel to **@userinfobot** on Telegram.
2. The bot will reply with the channel ID.

---

## Step 5 — Add Secrets to GitHub

1. Open your repository on GitHub.
2. Go to **Settings → Secrets and variables → Actions**.
3. Click **New repository secret**.
4. Add each secret:

| Name | Value |
|------|-------|
| `TELEGRAM_BOT_TOKEN` | The bot token from Step 1 (e.g. `123456789:ABCdefGhIjKlMnOpQrStUvWxYz`) |
| `TELEGRAM_CHAT_ID` | The channel ID from Step 4 (e.g. `-1001234567890` or `@my_videos_channel`) |

> **Security note:** Never commit these values to the repository. Keep them only in
> GitHub Secrets.

---

## Step 6 — Run the Workflow

1. Go to **Actions → Process Videos → Run workflow**.
2. Set `upload_telegram` to **yes**.
3. Optionally configure `upload_mirror` and `cloud_folder` for additional cloud uploads.
4. Click **Run workflow**.

Processed `.mp4` files (under 50 MB) will be uploaded to your Telegram channel
automatically after encoding.

---

## File Size Limit

The Telegram Bot API allows uploading files up to **50 MB** via the `sendVideo` method.
Videos larger than 50 MB are automatically skipped during the Telegram upload phase.

**Workarounds for large files:**

| Option | Description |
|--------|-------------|
| Higher CRF | Increase the CRF value in the workflow (e.g. from 15 to 23) to reduce file size |
| Cloud upload | Use `upload_mirror` to send large files to Dropbox or Google Drive instead |
| GitHub Release | All processed files (regardless of size) are always included in the GitHub Release ZIP parts |

---

## Troubleshooting

| Error | Fix |
|-------|-----|
| `TELEGRAM_BOT_TOKEN secret is not set` | Add the secret in GitHub Settings (Step 5) |
| `TELEGRAM_CHAT_ID secret is not set` | Add the secret in GitHub Settings (Step 5) |
| `Failed to upload … (HTTP 401)` | Bot token is invalid — regenerate with @BotFather |
| `Failed to upload … (HTTP 400)` | Chat ID is wrong or bot is not a channel admin |
| `Failed to upload … (HTTP 413)` | File exceeds 50 MB — reduce quality or use cloud upload |
| `exceeds 50 MB limit, skipped` | Expected behavior — file is too large for Telegram |
| Upload is slow | Telegram API speed depends on server load; `--max-time 600` allows up to 10 min per file |

---

## Token Refresh

Telegram bot tokens **do not expire** unless you revoke them via @BotFather (`/revoketoken`).
If you revoke a token, generate a new one and update the `TELEGRAM_BOT_TOKEN` GitHub Secret.
