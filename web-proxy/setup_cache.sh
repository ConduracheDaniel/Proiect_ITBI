#!/bin/bash

CACHE_DIR="/mnt/proxy_cache"
CACHE_SIZE="100M"

echo "[Setup] Creating cache directory..."
sudo mkdir -p "$CACHE_DIR"

echo "[Setup] Mounting tmpfs..."
sudo mount -t tmpfs -o size=$CACHE_SIZE tmpfs "$CACHE_DIR"

echo "[Setup] Done."
df -h | grep proxy_cache