#!/usr/bin/env bash
# Builds the site for Mercury and puts everything to upload in one folder:
#   bash scripts/build-mercury.sh [output-folder]
# Default output: ../deploy/rob (next to the repo, never committed).
# Upload the CONTENTS of that folder to the "rob" folder of your Mercury
# web space, so index.html ends up at https://mercury.swin.edu.au/cos30043/<id>/rob/
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:-$REPO/../deploy/rob}"
# Read the site's path from .env.mercury so there is one place to change it
BASE=$(grep '^VITE_BASE=' "$REPO/frontend/.env.mercury" | cut -d= -f2)

if [ ! -f "$REPO/backend/config/db.php" ]; then
  echo "backend/config/db.php is missing: copy db.example.php and fill in the Mercury database login." >&2
  exit 1
fi

echo "Building the Vue app for $BASE"
(cd "$REPO/frontend" && npm run build -- --mode mercury)

rm -rf "$OUT"
mkdir -p "$OUT/backend/config" "$OUT/backend/uploads"

# 1. The built app (index.html + assets/)
cp -r "$REPO/frontend/dist/." "$OUT/"

# 2. The API, the real database login and the seed photos. Not copied:
#    db.local.php (would point the live site at XAMPP), tests, SQL files,
#    and photos uploaded locally.
cp -r "$REPO/backend/api" "$OUT/backend/"
cp "$REPO/backend/config/db.php" "$REPO/backend/config/.htaccess" "$OUT/backend/config/"
cp "$REPO/backend/uploads/.htaccess" "$OUT/backend/uploads/"
cp -r "$REPO/backend/uploads/seed" "$OUT/backend/uploads/"

# 3. Page refresh on /properties/5 etc.: send any path that isn't a real
#    file or the API to index.html, where Vue Router takes over
cat > "$OUT/.htaccess" <<HTACCESS
<IfModule mod_rewrite.c>
    RewriteEngine On
    RewriteBase $BASE
    RewriteCond %{REQUEST_URI} !/backend/
    RewriteCond %{REQUEST_FILENAME} !-f
    RewriteCond %{REQUEST_FILENAME} !-d
    RewriteRule ^ index.html [L]
</IfModule>
HTACCESS

echo
echo "Ready to upload: $OUT"
find "$OUT" -maxdepth 2 | sed "s#^$OUT#rob#" | sort
