#!/bin/bash

# Optional: ensure we are in correct directory
cd "$(dirname "$0")"

if [ ! -f ".env" ]; then
    echo "⚠️ .env file not found!"
    exit 1
fi

# Load local secrets
set -a
source .env
set +a

# 2. Define the notification function properly
send_telegram() {
    local FOOTER=".
    
                        _via Crave Remote Build_"
    local FINAL_TEXT="${1}${FOOTER}"

    curl -s -X POST "https://api.telegram.org/bot${TG_TOKEN}/sendMessage" \
        --data-urlencode "chat_id=${TG_CHAT}" \
        --data-urlencode "message_thread_id=${TG_TOPIC}" \
        --data-urlencode "parse_mode=Markdown" \
        --data-urlencode "disable_web_page_preview=true" \
        --data-urlencode "text=${FINAL_TEXT}" >/dev/null
}

# Load build configurations
curl -sf https://raw.githubusercontent.com/nuruszama/crave_build_script/main/build_config.sh -o build_config.sh
source build_config.sh

# Fetch and load the funny messages from another file
curl -sf https://raw.githubusercontent.com/nuruszama/crave_build_script/main/messages.sh -o messages.sh
source messages.sh

# Pick a random index
RANDOM_MSG=${MESSAGES[$RANDOM % ${#MESSAGES[@]}]}

# Build Queue notification
send_telegram "$RANDOM_MSG"

# Run your GitHub-hosted script
echo "🚀 Starting remote build queue..."
crave run --projectID 93 --no-patch -- 'curl -sf https://raw.githubusercontent.com/nuruszama/crave_build_script/main/crave_run.sh | bash'
