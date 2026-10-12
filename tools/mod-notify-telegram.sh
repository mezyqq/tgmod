#!/usr/bin/env bash
# Sends a build to Telegram through a bot.
# usage: TG_BOT_TOKEN=... TG_CHAT_ID=... mod-notify-telegram.sh <file.ipa> <download-url> <text>
# Bots can upload files up to 50 MB; bigger builds are sent as a download link.
set -euo pipefail

FILE="$1"
URL="$2"
TEXT="$3"
API="https://api.telegram.org/bot${TG_BOT_TOKEN:?TG_BOT_TOKEN is not set}"
: "${TG_CHAT_ID:?TG_CHAT_ID is not set}"

SIZE=$(wc -c < "$FILE")
SIZE_MB=$(( (SIZE + 1048575) / 1048576 ))
LIMIT=$(( 50 * 1024 * 1024 ))

if [ "$SIZE" -le "$LIMIT" ]; then
  curl -sS --fail-with-body -F chat_id="$TG_CHAT_ID" -F document=@"$FILE" -F caption="$TEXT" "$API/sendDocument" > /dev/null
else
  curl -sS --fail-with-body "$API/sendMessage" \
    --data-urlencode chat_id="$TG_CHAT_ID" \
    --data-urlencode text="$TEXT

📦 ${SIZE_MB} МБ — больше лимита ботов (50 МБ), поэтому ссылкой:
$URL" > /dev/null
fi
echo "sent to Telegram"
