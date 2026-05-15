# Crave Custom ROM Build Scripts 🚀
Instruction is still under maintenance.. will be updated soon.

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
UPLOAD="your_telegram_log_channel_id"
PIXELDRAIN="your_pixeldrain_api_key"
GITHUB="your_github_token"
```


###. Running a Build
To start a build for the POCO M7 (**creek**), execute the following command in your terminal:

```bash
crave run --projectID 93 --no-patch -- 'curl -sf https://raw.githubusercontent.com/nuruszama/crave_build_script/main/crave_run.sh | bash'
```

---

## 🤝 Credits

A huge thanks to the original author for the foundation of these scripts:

*   **[EternalMikaelson](https://github.com/EternalMikaelson)** - For the original script architecture, automated workflow logic, and Telegram integration.
*   
