#!/bin/bash
CACHE_DIR="/mnt/proxy_cache"

URL="$1"
if [ -z "$URL" ]; then
    echo "Eroare: Nu a fost furnizat niciun URL." >&2
    exit 1
fi

FILENAME=$(echo -n "$URL" | md5sum | awk '{print $1}').html
CACHE_FILE="$CACHE_DIR/$FILENAME"

clean_lru() {
    local THRESHOLD=85 
    
    local usage=$(df "$CACHE_DIR" | awk 'NR==2 {print $5}' | sed 's/%//')

    while [ "$usage" -gt "$THRESHOLD" ]; do
        local oldest=$(ls -tu "$CACHE_DIR"/*.html 2>/dev/null | tail -1)
        
        if [ -n "$oldest" ]; then
            echo "[LRU] Cache aproape plin ($usage%). Se elimină: $(basename "$oldest")" >&2
            rm -f "$oldest"
            usage=$(df "$CACHE_DIR" | awk 'NR==2 {print $5}' | sed 's/%//')
        else
            break 
        fi
    done
}

if [ -f "$CACHE_FILE" ]; then
    echo "[Proxy] CACHE HIT pentru $URL" >&2

    touch -a "$CACHE_FILE"
    
    ln -sf "$CACHE_FILE"
    
    echo "$CACHE_FILE"
    exit 0
fi

echo "[Proxy] CACHE MISS pentru $URL" >&2

clean_lru

touch "$CACHE_FILE"
ln -sf "$CACHE_FILE"

wget -q -O "$CACHE_FILE" "$URL" &
WGET_PID=$!

inotifywait -e close_write "$CACHE_FILE" >/dev/null 2>&1

wait $WGET_PID

echo "[Proxy] Descărcare finalizată, servesc din cache." >&2
echo "$CACHE_FILE"
exit 0