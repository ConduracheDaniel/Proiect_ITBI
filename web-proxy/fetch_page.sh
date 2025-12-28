#!/bin/bash

# === CONFIGURARE ===
# Directorul unde se montează tmpfs (trebuie să existe și să fie limitat ca spațiu)
CACHE_DIR="/mnt/proxy_cache"
# Director pentru link-uri simbolice (cerință proiect pentru vizibilitate/temp)
TMP_DIR="$(pwd)/tmp/proxy_temp_copy"

# Creare directoare necesare
mkdir -p "$CACHE_DIR" "$TMP_DIR"

URL="$1"
if [ -z "$URL" ]; then
    echo "Eroare: Nu a fost furnizat niciun URL." >&2
    exit 1
fi

# Generăm un nume unic de fișier folosind MD5 pentru a evita caracterele speciale din URL
FILENAME=$(echo -n "$URL" | md5sum | awk '{print $1}').html
CACHE_FILE="$CACHE_DIR/$FILENAME"
TMP_LINK="$TMP_DIR/$FILENAME"

# === FUNCȚIE LRU (Least Recently Used) ===
# Această funcție menține dimensiunea cache-ului sub control
clean_lru() {
    local THRESHOLD=85 # Ștergem dacă ocuparea trece de 85%
    
    # Verificăm spațiul pe partiția tmpfs
    local usage=$(df "$CACHE_DIR" | awk 'NR==2 {print $5}' | sed 's/%//')

    while [ "$usage" -gt "$THRESHOLD" ]; do
        # Identificăm cel mai vechi fișier accesat (LRU)
        # ls -tu sortează după 'atime' (access time), tail -1 ia ultimul element
        local oldest=$(ls -tu "$CACHE_DIR"/*.html 2>/dev/null | tail -1)
        
        if [ -n "$oldest" ]; then
            echo "[LRU] Cache aproape plin ($usage%). Se elimină: $(basename "$oldest")" >&2
            rm -f "$oldest"
            # Actualizăm valoarea spațiului ocupat
            usage=$(df "$CACHE_DIR" | awk 'NR==2 {print $5}' | sed 's/%//')
        else
            break # Nu mai sunt fișiere de șters
        fi
    done
}

# === LOGICĂ PROXY ===

# 1. CACHE HIT: Pagina există deja
if [ -f "$CACHE_FILE" ]; then
    echo "[Proxy] CACHE HIT pentru $URL" >&2
    
    # ACTUALIZARE LRU: Reînnoim timpul de acces pentru a nu fi șters curând
    touch -a "$CACHE_FILE"
    
    # Creăm link-ul către fișierul din RAM
    ln -sf "$CACHE_FILE" "$TMP_LINK"
    
    # Returnăm calea pentru serverul Web
    echo "$CACHE_FILE"
    exit 0
fi

# 2. CACHE MISS: Pagina trebuie descărcată
echo "[Proxy] CACHE MISS pentru $URL" >&2

# Verificăm dacă avem spațiu în tmpfs folosind LRU înainte de download
clean_lru

# Creăm un fișier gol pentru a putea seta link-ul și monitorizarea
touch "$CACHE_FILE"
ln -sf "$CACHE_FILE" "$TMP_LINK"

# Pornim wget în fundal (background)
wget -q -O "$CACHE_FILE" "$URL" &
WGET_PID=$!

# Monitorizăm fișierul: așteptăm până când scrierea s-a finalizat (inotify)
# -e close_write înseamnă "așteaptă până când procesul care scrie a închis fișierul"
inotifywait -e close_write "$CACHE_FILE" >/dev/null 2>&1

# Ne asigurăm că procesul wget s-a terminat
wait $WGET_PID

echo "[Proxy] Descărcare finalizată, servesc din cache." >&2
echo "$CACHE_FILE"
exit 0