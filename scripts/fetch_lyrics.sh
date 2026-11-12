#!/usr/bin/env bash
TITLE="$1"
ARTIST="$2"
CACHE_DIR="$HOME/.cache/vortex-linux/lyrics"
mkdir -p "$CACHE_DIR"

if [ -z "$TITLE" ]; then
    exit 0
fi

SAFE_KEY=$(echo "${ARTIST}_${TITLE}" | tr -dc '[:alnum:]_-' | tr '[:upper:]' '[:lower:]')
CACHE_FILE="$CACHE_DIR/${SAFE_KEY}.lrc"

if [ -s "$CACHE_FILE" ]; then
    cat "$CACHE_FILE"
    exit 0
fi

RESPONSE=$(curl -sG "https://lrclib.net/api/search" \
    --data-urlencode "track_name=$TITLE" \
    --data-urlencode "artist_name=$ARTIST" | jq -r '.[0].syncedLyrics // empty' 2>/dev/null)

if [ -z "$RESPONSE" ]; then
    RESPONSE=$(curl -sG "https://lrclib.net/api/search" \
        --data-urlencode "q=$TITLE $ARTIST" | jq -r '[.[] | select(.syncedLyrics != null)][0].syncedLyrics // empty' 2>/dev/null)
fi

if [ -n "$RESPONSE" ]; then
    echo "$RESPONSE" > "$CACHE_FILE"
    cat "$CACHE_FILE"
fi
