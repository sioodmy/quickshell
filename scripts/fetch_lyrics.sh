#!/usr/bin/env bash
ARTIST="$1"
TITLE="$2"

if [ -z "$ARTIST" ] || [ -z "$TITLE" ]; then
    exit 1
fi

CACHE_DIR="$HOME/.cache/quickshell/lyrics"
mkdir -p "$CACHE_DIR"

# Clean filename
FILENAME=$(echo "${ARTIST}-${TITLE}" | sed -e 's/[^A-Za-z0-9._-]/_/g').lrc
CACHE_FILE="$CACHE_DIR/$FILENAME"

if [ -f "$CACHE_FILE" ]; then
    cat "$CACHE_FILE"
    exit 0
fi

ARTIST_ENC=$(printf %s "$ARTIST" | jq -sRr @uri)
TITLE_ENC=$(printf %s "$TITLE" | jq -sRr @uri)

URL="https://lrclib.net/api/get?track_name=$TITLE_ENC&artist_name=$ARTIST_ENC"
RES=$(curl -sL "$URL")

# lrclib returns JSON with "syncedLyrics" key. If null or not found, it returns empty.
SYNCED=$(echo "$RES" | jq -r '.syncedLyrics // empty')

if [ -n "$SYNCED" ]; then
    echo "$SYNCED" > "$CACHE_FILE"
    echo "$SYNCED"
else
    # Save empty placeholder so it doesn't spam requests repeatedly
    echo "" > "$CACHE_FILE"
    echo ""
fi
