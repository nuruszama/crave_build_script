# Crave Custom ROM Build Scripts 🚀

This repository contains highly automated build scripts optimized for building custom Android ROMs (specifically LineageOS) using the **Crave.io** build environment. 

These scripts handle the entire lifecycle of a build: from environment preparation and source synchronization to automated notifications and artifact distribution.

---

## ✨ Features
*   **Automated Tooling:** Self-installs dependencies like `jq` if missing.
*   **Smart Sync:** Integrates with Crave's native resync logic for maximum speed.
*   **Real-time Notifications:** Sends build status, sync times, and errors directly to Telegram.
*   **Artifact Hosting:** Automatically uploads successful builds (`.zip`) and partition images (`.img`) to **PixelDrain** and **GoFile**.
*   **Error Logging:** On failure, the script captures and uploads build logs to help with debugging.

---

## 🛠️ Setup & Usage

### 1. Prerequisites
You must have a **Crave.io** account and the `crave` CLI tool configured on your local machine or devspace.

### 2. Secrets Management
Create a `.env` file in your project root. **Never commit this file to GitHub.**

```env
TG_TOKEN="your_telegram_bot_token"
TG_CHAT="your_telegram_chat_id"
PIXELDRAIN="your_pixeldrain_api_key"
```
*   **TG_TOKEN** will be used to integrate your telegram bot to your script.
*   **TG_CHAT** is the telegram chat_id to which you want to send telegram notifications.
*   **PIXELDRAIN** is your pixeldrain api. This is required to upload your files from the crave out after successful build.

### 3. Setting Build Configurations
By editing the **build_config.sh**, you can change the container time zone to your timezone, define the basic details of your build.

### 4. Adding custom messages for queue notification
The script uses random messages in telegram to notify the users that the build has been successfully queued. If you required to edit or add any custom messages of your own, you can do the same by editing messages.sh.
Minimal messages.sh looks like
```
MESSAGES=(
"<Your
Custom
Message>"
)
```

### 5. Running the Build
To start a build inside the crave, execute the following command in your crave-devspaces terminal:
```
curl -sf https://raw.githubusercontent.com/nuruszama/crave_build_scripts/blob/lineage-23.2/crave_build.sh | bash
```
Don't forget to replace the above script link with your own.

---

## Push the .env file to the root of the Crave workspace
Additionally, you can push your .env file to crave server/workspace using the following script
```
crave push .env -d /tmp/src/android
```

---

# 🤝 Credits

A huge thanks to the original author for the foundation of these scripts:

*   **[EternalMikaelson](https://github.com/EternalMikaelson)** - For the original script architecture, automated workflow logic, and Telegram integration.
*   **[SoundDrill31](https://github.com/sounddrill31)** - For helping me to understand how to push the .env file to the workspace
*   **[{⚡}crave.io](https://crave.io/)** - For giving the the free server to the developers who doesn't have a workspace 
