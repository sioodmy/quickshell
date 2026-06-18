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
RES=$(curl --max-time 10 -sL "$URL")

# Check if response is valid JSON
if ! echo "$RES" | jq . >/dev/null 2>&1; then
    # Not valid JSON (e.g. 504 Gateway Timeout). Do not cache.
    echo "ERROR_API_FAILED"
    exit 1
fi

# Extract syncedLyrics and statusCode
SYNCED=$(echo "$RES" | jq -r '.syncedLyrics // empty')
STATUS=$(echo "$RES" | jq -r '.statusCode // 200')

if [ -n "$SYNCED" ]; then
    printf "%s\n" "$SYNCED" > "$CACHE_FILE"
    printf "%s\n" "$SYNCED"
else
    # Save empty placeholder only if track is not found or has no synced lyrics
    if [ "$STATUS" = "404" ] || [ "$STATUS" = "200" ]; then
        printf "\n" > "$CACHE_FILE"
        printf "\n"
    else
        # Do not cache server errors (e.g., 429, 503)
        echo "ERROR_API_FAILED"
        exit 1
    fi
fi
