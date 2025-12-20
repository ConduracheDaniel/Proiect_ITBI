#!/bin/bash
 
# === CONFIG ===
# 1. Locația principală de cache (specificată de utilizator, ex: pe /mnt)
CACHE_DIR="$(pwd)/proxy_cache"
 
# 2. Locația temporară (simulând tmpfs, de obicei /tmp)
TMP_DIR="$(pwd)/tmp/proxy_temp_copy"
 
# Creare directoare daca nu exista
mkdir -p "$CACHE_DIR"
mkdir -p "$TMP_DIR"
 
URL="$1"
if [ -z "$URL" ]; then
    echo "Error: no URL provided"
    exit 1
fi
 
# Generam nume de fisier pe baza hash-ului URL-ului
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
fi
 
echo "[Proxy] File copied to temporary location: $TMP_FILEPATH"
echo ""
 
# Pentru ieșire, returnăm calea finală din cache
echo "$CACHE_FILEPATH"
exit 0