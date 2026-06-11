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

# Enhanced Bash Function supporting optional icon pathing
generate_flat_badge() {
    local label="$1"
    local value="$2"
    local label_color="$3"
    local value_color="$4"
    local out_file="$5"
    local icon_path="$6" # Optional parameter for raw SVG path data

    local label_len=${#label}
    local value_len=${#value}
    
    local label_width=$((label_len * 7 + 14))
    local value_width=$((value_len * 7 + 14))
    
    local icon_element=""
    local label_text_x
    
    if [ -n "$icon_path" ]; then
        # Add 18px width for a 14px icon + padding layout
        label_width=$((label_width + 18))
        # Recalculate text center placement to account for icon layout shift
        label_text_x=$(( 95 + (label_width * 5) ))
        # Viewbox is 24x24 natively; scale(0.5833) maps it perfectly to a 14x14 size
        icon_element="<g transform=\"translate(5,3) scale(0.5833)\" fill=\"#fff\"><path d=\"$icon_path\"/></g>"
    else
        label_text_x=$((label_width * 5))
    fi
    
    local total_width=$((label_width + value_width))
    local value_text_x=$((label_width * 10 + value_width * 5))

    cat <<EOF > "$out_file"
<svg xmlns="http://www.w3.org/2000/svg" width="$total_width" height="20" role="img" aria-label="$label: $value">
  <g shape-rendering="crispEdges">
    <rect width="$label_width" height="20" fill="$label_color"/>
    <rect x="$label_width" width="$value_width" height="20" fill="$value_color"/>
  </g>
  $icon_element
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
    echo "[WARN] GITHUB_TOKEN environment variable is missing. Proceeding unauthenticated."
fi

# Fetch raw metrics directly via native GitHub API REST endpoints
REPO_DATA=$(curl -s -H "$AUTH_HEADER" "https://api.github.com/repos/$BADGE_REPO")
RELEASES_DATA=$(curl -s -H "$AUTH_HEADER" "https://api.github.com/repos/$BADGE_REPO/releases")

# Parse metrics out using jq
STARS_COUNT=$(echo "$REPO_DATA" | jq -r '.stargazers_count // "0"')
LATEST_DOWNLOADS=$(echo "$RELEASES_DATA" | jq -r 'if .[0] then [.[0].assets[].download_count] | add else 0 end')
TOTAL_DOWNLOADS=$(echo "$RELEASES_DATA" | jq -r '[.[].assets[].download_count] | add // 0')

BADGES_DIR="$BUILD_DIR/$RES_DIR/$BADGES_SUBDIR"

# Raw path extracted from your SVG element
GITHUB_ICON_PATH="M12 0C5.374 0 0 5.373 0 12c0 5.302 3.438 9.8 8.207 11.387.599.111.793-.261.793-.577v-2.234c-3.338.726-4.033-1.416-4.033-1.416-.546-1.387-1.333-1.756-1.333-1.756-1.089-.745.083-.729.083-.729 1.205.084 1.839 1.237 1.839 1.237 1.07 1.834 2.807 1.304 3.492.997.107-.775.418-1.305.762-1.604-2.665-.305-5.467-1.334-5.467-5.931 0-1.311.469-2.381 1.236-3.221-.124-.303-.535-1.524.117-3.176 0 0 1.008-.322 3.301 1.23.957-.266 1.983-.399 3.003-.404 1.02.005 2.047.138 3.006.404 2.291-1.552 3.297-1.23 3.297-1.23.653 1.653.242 2.874.118 3.176.77.84 1.235 1.911 1.235 3.221 0 4.609-2.807 5.624-5.479 5.921.43.372.823 1.102.823 2.222v3.293c0 .319.192.694.801.576C20.566 21.797 24 17.3 24 12c0-6.627-5.373-12-12-12z"

# Generate the SVGs (passing the icon variable exclusively into the stars badge)
generate_flat_badge "stars" "$STARS_COUNT" "#16161f" "#f59e0b" "$BADGES_DIR/stars.svg" "$GITHUB_ICON_PATH"
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