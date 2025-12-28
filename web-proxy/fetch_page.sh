#!/bin/bash
 
# === CONFIG ===
# 1. Locația principală de cache (specificată de utilizator, ex: pe /mnt)

CACHE_DIR="$(pwd)/proxy_cache"
TMP_DIR="$(pwd)/tmp/proxy_temp_copy"
 
# Creare directoare daca nu exista
mkdir -p "$CACHE_DIR"
mkdir -p "$TMP_DIR"
 

mkdir -p "$CACHE_DIR" "$TMP_DIR"

URL="$1"
if [ -z "$URL" ]; then
    echo "Error: no URL provided"
    exit 1
fi
 
# Generam nume de fisier pe baza hash-ului URL-ului
[ -z "$URL" ] && exit 1

FILENAME=$(echo -n "$URL" | md5sum | awk '{print $1}').html
 
# Calea finală (Cache-ul persistent)
CACHE_FILEPATH="$CACHE_DIR/$FILENAME"
 
# Calea temporară (Copie rapidă/tmpfs)
TMP_FILEPATH="$TMP_DIR/$FILENAME"
 
 
# === CACHE MISS: descarcam pagina ===
echo "[Proxy] Downloading: $URL" >&2
echo "        -> Final Cache: $CACHE_FILEPATH"
echo "        -> Temp Copy:   $TMP_FILEPATH"
 
# wget descarca direct in CACHE_DIR
wget -q -O "$CACHE_FILEPATH" "$URL"
 
EXIT_CODE=$?
 
if [ $EXIT_CODE -ne 0 ]; then
    echo "[Proxy] ERROR: wget failed"
    rm -f "$CACHE_FILEPATH"
    exit 2
fi
 
echo "[Proxy] Download complete to primary cache."
 
# === COPIEREA ÎN DIRECTORUL TEMPORAR (TMP) ===
# Se copiază fișierul proaspăt descărcat în directorul temporar.
# Acest pas simulează salvarea în tmpfs pentru operațiuni rapide/servire imediată.
cp "$CACHE_FILEPATH" "$TMP_FILEPATH"
 
if [ $? -ne 0 ]; then
    echo "[Proxy] WARNING: Could not copy file to temporary location ($TMP_DIR). Continue anyway."
    # Nu ieșim din script, deoarece fișierul este deja salvat în CACHE_DIR.
CACHE_FILE="$CACHE_DIR/$FILENAME"
TMP_LINK="$TMP_DIR/$FILENAME"


# CACHE HIT
if [ -f "$CACHE_FILE" ]; then
    echo "[Proxy] CACHE HIT" >&2
    ln -sf "$CACHE_FILE" "$TMP_LINK"
    echo "$CACHE_FILE"
    exit 0
fi
 
echo "[Proxy] File copied to temporary location: $TMP_FILEPATH"
echo ""
 
# Pentru ieșire, returnăm calea finală din cache
echo "$CACHE_FILEPATH"


# CACHE MISS
echo "[Proxy] CACHE MISS" >&2

# Creează fișier gol + link local
touch "$CACHE_FILE"
ln -sf "$CACHE_FILE" "$TMP_LINK"

# Pornește wget în background
wget -q -O "$CACHE_FILE" "$URL" &

WGET_PID=$!

# Așteaptă finalizarea scrierii fișierului
inotifywait -e close_write "$CACHE_FILE" >/dev/null

wait $WGET_PID

echo "[Proxy] Download complete, serving from cache" >&2
echo "$CACHE_FILE"
exit 0