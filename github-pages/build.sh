#!/bin/bash

# --- CONFIGURATION ---
SRC_DIR="src"
BUILD_DIR="build"
RES_DIR="resources"
INDEX_FILE="index.html"

# Repository identifier for badges
BADGE_REPO="kulvind3r/gaminggaiden"
BADGES_SUBDIR="badges"

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
mkdir -p "$BUILD_DIR/$RES_DIR/$BADGES_SUBDIR"

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

# --- NATIVE LOCAL BADGE GENERATOR ---
echo "[BUILD] Generating native SVG badges locally..."

# Pure Bash Function to build flat-square SVGs dynamically
generate_flat_badge() {
    local label="$1"
    local value="$2"
    local label_color="$3"
    local value_color="$4"
    local out_file="$5"

    local label_len=${#label}
    local value_len=${#value}
    
    # Calculate widths dynamically (approx 7px per character + padding)
    local label_width=$((label_len * 7 + 14))
    local value_width=$((value_len * 7 + 14))
    local total_width=$((label_width + value_width))
    
    # Text positioning anchors
    local label_text_x=$((label_width * 5))
    local value_text_x=$((label_width * 10 + value_width * 5))

    cat <<EOF > "$out_file"
<svg xmlns="http://www.w3.org/2000/svg" width="$total_width" height="20" role="img" aria-label="$label: $value">
  <g shape-rendering="crispEdges">
    <rect width="$label_width" height="20" fill="$label_color"/>
    <rect x="$label_width" width="$value_width" height="20" fill="$value_color"/>
  </g>
  <g fill="#fff" text-anchor="middle" font-family="Verdana,Geneva,sans-serif" text-rendering="geometricPrecision" font-size="110">
    <text x="$label_text_x" y="140" transform="scale(.1)" fill="#fff" textLength="$((label_len * 65))">$label</text>
    <text x="$value_text_x" y="140" transform="scale(.1)" fill="#fff" textLength="$((value_len * 65))">$value</text>
  </g>
</svg>
EOF
    echo "[BADGE] Created $(basename "$out_file") ($label: $value)"
}

# Setup GitHub API Authentication Header using Environment Secret
AUTH_HEADER=""
if [ -n "$GITHUB_TOKEN" ]; then
    AUTH_HEADER="Authorization: token $GITHUB_TOKEN"
else
    echo "[WARN] GITHUB_TOKEN environment variable is missing. Proceeding unauthenticated (subject to lower API limits)."
fi

# Fetch raw metrics directly via native GitHub API REST endpoints
REPO_DATA=$(curl -s -H "$AUTH_HEADER" "https://api.github.com/repos/$BADGE_REPO")
RELEASES_DATA=$(curl -s -H "$AUTH_HEADER" "https://api.github.com/repos/$BADGE_REPO/releases")

# Parse metrics out using jq (Standard utility available on GitHub runners)
STARS_COUNT=$(echo "$REPO_DATA" | jq -r '.stargazers_count // "0"')
LATEST_DOWNLOADS=$(echo "$RELEASES_DATA" | jq -r 'if .[0] then [.[0].assets[].download_count] | add else 0 end')
TOTAL_DOWNLOADS=$(echo "$RELEASES_DATA" | jq -r '[.[].assets[].download_count] | add // 0')

BADGES_DIR="$BUILD_DIR/$RES_DIR/$BADGES_SUBDIR"

# Generate the three flat-square SVGs completely offline
generate_flat_badge "stars" "$STARS_COUNT" "#16161f" "#f59e0b" "$BADGES_DIR/stars.svg"
generate_flat_badge "Downloads - Latest" "$LATEST_DOWNLOADS" "#16161f" "#3b82f6" "$BADGES_DIR/downloads-latest.svg"
generate_flat_badge "Downloads - Total" "$TOTAL_DOWNLOADS" "#16161f" "#3b82f6" "$BADGES_DIR/downloads-total.svg"

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