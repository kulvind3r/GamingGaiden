#!/bin/bash

# --- CONFIGURATION ---
SRC_DIR="src"
BUILD_DIR="build"
RES_DIR="resources"
INDEX_FILE="index.html"

# JS and CSS assets to fingerprint (cache-bust on content change)
FINGERPRINT_FILES=("script.js" "style.css")

# Assets copied as-is (no fingerprinting needed)
COPY_FILES=("favicon.ico" "banner.png")

echo "[BUILD] Starting Gaming Gaiden github-pages build..."
echo "--------------------------------------------------"

# --- CLEAN & PREPARE BUILD DIRECTORIES ---
if [ -d "$BUILD_DIR" ]; then
    echo "[CLEAN] Wiping existing '$BUILD_DIR' directory..."
    rm -rf "$BUILD_DIR"
fi
echo "[DIR] Creating fresh '$BUILD_DIR' and subdirectories..."
mkdir -p "$BUILD_DIR/$RES_DIR/screenshots"

# --- COPY INDEX.HTML ---
if [ -f "$SRC_DIR/$INDEX_FILE" ]; then
    echo "[COPY] Copying $INDEX_FILE to $BUILD_DIR..."
    cp "$SRC_DIR/$INDEX_FILE" "$BUILD_DIR/$INDEX_FILE"
else
    echo "[ERROR] $INDEX_FILE not found in $SRC_DIR!"
    exit 1
fi

# --- COPY content.json (carousel + features + shields) ---
if [ -f "$SRC_DIR/content.json" ]; then
    echo "[COPY] Copying content.json..."
    cp "$SRC_DIR/content.json" "$BUILD_DIR/content.json"
else
    echo "[WARN] content.json not found - skipping."
fi

# --- COPY UNFINGERPRINTED ASSETS ---
for FILE in "${COPY_FILES[@]}"; do
    SRC_PATH="$SRC_DIR/$RES_DIR/$FILE"
    if [ -f "$SRC_PATH" ]; then
        echo "[COPY] $RES_DIR/$FILE"
        cp "$SRC_PATH" "$BUILD_DIR/$RES_DIR/$FILE"
    else
        echo "[WARN] File not found: $SRC_PATH - Skipping."
    fi
done

# --- COPY SCREENSHOTS ---
if [ -d "$SRC_DIR/$RES_DIR/screenshots" ]; then
    SCREENSHOT_COUNT=$(find "$SRC_DIR/$RES_DIR/screenshots" -maxdepth 1 -type f | wc -l | tr -d ' ')
    if [ "$SCREENSHOT_COUNT" -gt 0 ]; then
        echo "[COPY] Copying $SCREENSHOT_COUNT screenshot(s)..."
        cp "$SRC_DIR/$RES_DIR/screenshots/"* "$BUILD_DIR/$RES_DIR/screenshots/" 2>/dev/null
    else
        echo "[INFO] No screenshots found in screenshots/ - directory created but empty."
    fi
fi

# --- FINGERPRINT JS & CSS ---
echo "[BUILD] Processing fingerprinted assets..."

for FILE in "${FINGERPRINT_FILES[@]}"; do
    SRC_PATH="$SRC_DIR/$RES_DIR/$FILE"

    if [ -f "$SRC_PATH" ]; then
        NAME="${FILE%.*}"
        EXT=".${FILE##*.}"

        if command -v sha256sum &> /dev/null; then
            HASH=$(sha256sum "$SRC_PATH" | cut -c 1-8)
        elif command -v shasum &> /dev/null; then
            HASH=$(shasum -a 256 "$SRC_PATH" | cut -c 1-8)
        else
            HASH=$(md5sum "$SRC_PATH" | cut -c 1-8)
        fi

        NEW_FILE_NAME="${NAME}.${HASH}${EXT}"
        echo "[PROCESS] $RES_DIR/$FILE -> $RES_DIR/$NEW_FILE_NAME"
        cp "$SRC_PATH" "$BUILD_DIR/$RES_DIR/$NEW_FILE_NAME"

        sed -i.bak -E "s|${RES_DIR}/${NAME}(\.[a-fA-F0-9]+)?${EXT}|${RES_DIR}/${NEW_FILE_NAME}|g" "$BUILD_DIR/$INDEX_FILE"
        rm -f "$BUILD_DIR/$INDEX_FILE.bak"
    else
        echo "[WARN] File not found: $SRC_PATH - Skipping."
    fi
done

echo "--------------------------------------------------"
echo "[BUILD] Production build created in '$BUILD_DIR'!"
