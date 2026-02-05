#!/usr/bin/env bash
set -euo pipefail

# Moltbook Quant Analysis Auto-Scanner
# - Reads Moltbook via the official API
# - Writes learning notes into memory/YYYY-MM-DD.md
# - Tracks viewed post_ids in state/viewed-posts.json
#
# SECURITY:
# - API key must come from env var: MOLTBOOK_API_KEY
# - Only calls https://www.moltbook.com/api/v1/* (www required)

API_KEY="${MOLTBOOK_API_KEY:-}"
BASE_URL="https://www.moltbook.com/api/v1"
WORKSPACE="${WORKSPACE:-/workspace}"
STATE_FILE="$WORKSPACE/state/viewed-posts.json"
MEMORY_DIR="$WORKSPACE/memory"
LOG_DIR="$WORKSPACE/logs"
TODAY="$(date +%Y-%m-%d)"
NOW_HUMAN="$(date +%Y-%m-%d\ %H:%M:%S)"

mkdir -p "$MEMORY_DIR" "$WORKSPACE/state" "$LOG_DIR"

if [[ -z "$API_KEY" ]]; then
  echo "[$(date)] ERROR: MOLTBOOK_API_KEY is not set; refusing to run." >&2
  exit 2
fi

# Initialize state file if missing or invalid
if [[ ! -f "$STATE_FILE" ]] || ! jq -e . "$STATE_FILE" >/dev/null 2>&1; then
  echo '{"viewed_posts": [], "last_scan_ts": null}' > "$STATE_FILE"
fi

# Load viewed posts into a jq-friendly set (array)
VIEWED_JSON="$(cat "$STATE_FILE" | jq -c '.viewed_posts // []')"

echo "[$(date)] Starting quant analysis scan..."

QUERIES=(
  "quantitative trading"
  "algorithmic trading"
  "machine learning"
  "stock market"
  "portfolio optimization"
)

new_posts=0

for q in "${QUERIES[@]}"; do
  query_enc="$(python3 -c 'import sys,urllib.parse; print(urllib.parse.quote_plus(sys.argv[1]))' "$q")"

  results_json="$(curl -fsS --max-time 30 "${BASE_URL}/search?q=${query_enc}&limit=25" \
    -H "Authorization: Bearer ${API_KEY}")" || {
      echo "[$(date)] Failed to fetch results for query: $q" >&2
      continue
    }

  # Extract unique post ids defensively (search can return posts/comments)
  while IFS= read -r post_id; do
    [[ -n "$post_id" ]] || continue
    # Skip if already viewed
    if echo "$VIEWED_JSON" | jq -e --arg id "$post_id" 'index($id) != null' >/dev/null; then
      continue
    fi

    post_json="$(curl -fsS --max-time 30 "${BASE_URL}/posts/${post_id}" \
      -H "Authorization: Bearer ${API_KEY}")" || {
        echo "[$(date)] Failed to fetch post: $post_id" >&2
        continue
      }

    title="$(echo "$post_json" | jq -r '.title // empty')"
    author="$(echo "$post_json" | jq -r '.author.name // empty')"
    upvotes="$(echo "$post_json" | jq -r '.upvotes // 0')"
    content="$(echo "$post_json" | jq -r '.content // empty')"

    if [[ -z "$title" || -z "$author" ]]; then
      echo "[$(date)] Skipping post (missing title/author): $post_id" >&2
      continue
    fi

    # Filter very short posts
    if (( ${#content} < 100 )); then
      continue
    fi

    memory_file="$MEMORY_DIR/$TODAY.md"
    if [[ ! -f "$memory_file" ]]; then
      {
        echo "# $TODAY Learning Notes"
        echo ""
      } > "$memory_file"
    fi

    cat >> "$memory_file" <<EOF

## Quant Analysis: $title
**Author**: $author | **Upvotes**: $upvotes | **ScannedAt**: $NOW_HUMAN
**Post ID**: $post_id
**Link**: https://www.moltbook.com/posts/$post_id

**Content**:
$content

---
EOF

    # Add to viewed set
    VIEWED_JSON="$(echo "$VIEWED_JSON" | jq -c --arg id "$post_id" '. + [$id] | unique')"
    new_posts=$((new_posts + 1))
  done < <(echo "$results_json" | jq -r '.. | .post_id? // empty' | sort -u)
done

# Persist state
jq -n --argjson viewed "$VIEWED_JSON" --argjson ts "$(date +%s)" '{viewed_posts:$viewed,last_scan_ts:$ts}' > "$STATE_FILE"

if (( new_posts > 0 )); then
  echo "[$(date)] Scan complete: $new_posts new posts learned"
else
  echo "[$(date)] Scan complete: no new posts found"
fi
