#!/usr/bin/env bash
# scrape_videos.sh — Crawl https://realsuperlandiaxxx.online/ with curl,
#   extract video links from Schema.org VideoObject metadata, and regenerate
#   video_urls.txt / url_list.txt.
#
# Usage:
#   ./scrape_videos.sh              # full crawl (all categories, all pages)
#   ./scrape_videos.sh --dry-run    # just list discovered post URLs, don't fetch each
#
# Output files (written to the repo root, or $OUTPUT_DIR if set):
#   video_urls.txt  — VIDEO_URL|CATEGORY|SITE|THUMBNAIL_URL|DURATION|UPLOAD_DATE
#   url_list.txt    — one bare video URL per line
set -euo pipefail

SITE_URL="https://realsuperlandiaxxx.online"
CATEGORIES=("brother" "daddy" "mommy")

# Configurable via env vars
MAX_RETRIES="${MAX_RETRIES:-3}"
RETRY_DELAY="${RETRY_DELAY:-2}"
CURL_TIMEOUT="${CURL_TIMEOUT:-30}"
CONCURRENT="${CONCURRENT:-10}"
OUTPUT_DIR="${OUTPUT_DIR:-.}"
DRY_RUN=false
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true

TMPDIR_SCRAPE=$(mktemp -d /tmp/scrape_videos.XXXXXX)
trap 'rm -rf "$TMPDIR_SCRAPE"' EXIT

# ── helpers ───────────────────────────────────────────────────────────────────

log()  { printf '[%s] %s\n' "$(date -u +%H:%M:%S)" "$*"; }
warn() { log "⚠️  $*" >&2; }

# Robust curl wrapper with retries
fetch() {
  local url="$1" dest="$2" attempt=0
  while (( attempt < MAX_RETRIES )); do
    if curl -sL -o "$dest" -w '' \
         --max-time "$CURL_TIMEOUT" --connect-timeout 10 \
         -H "User-Agent: Mozilla/5.0 (compatible; scrape_videos/1.0)" \
         "$url" 2>/dev/null; then
      # Verify we got actual content (not empty / tiny error page)
      local sz; sz=$(wc -c < "$dest")
      if (( sz > 500 )); then
        return 0
      fi
    fi
    (( attempt++ ))
    sleep "$RETRY_DELAY"
  done
  warn "Failed to fetch $url after $MAX_RETRIES attempts"
  return 1
}

# ── Phase 1: Discover post URLs from category listing pages ───────────────────

log "Phase 1 — Discovering post URLs from category listing pages …"

post_urls_file="$TMPDIR_SCRAPE/post_urls.txt"
: > "$post_urls_file"

for cat in "${CATEGORIES[@]}"; do
  page=1
  while true; do
    if (( page == 1 )); then
      url="${SITE_URL}/category/${cat}/"
    else
      url="${SITE_URL}/category/${cat}/page/${page}/"
    fi

    listing="$TMPDIR_SCRAPE/cat_${cat}_p${page}.html"
    if ! fetch "$url" "$listing"; then
      break
    fi

    # Check for 404-like content (WordPress returns 200 with "Nothing found")
    if grep -q 'class="error-404\|Nothing Found\|Page not found' "$listing" 2>/dev/null; then
      break
    fi

    # Extract post links: href="https://realsuperlandiaxxx.online/(brother|daddy|mommy)-NNN/"
    post_link_re="href=\"${SITE_URL}/(brother|daddy|mommy)-\\d+/\""
    links_found=0
    grep -oP "$post_link_re" "$listing" \
      | sed 's/href="//;s/"$//' \
      | sort -u >> "$post_urls_file"
    links_found=$(grep -oP "$post_link_re" "$listing" | sort -u | wc -l)

    # Also capture the base category URL (e.g., /brother/ without number)
    grep -oP "href=\"${SITE_URL}/${cat}/\"" "$listing" \
      | sed 's/href="//;s/"$//' \
      | sort -u >> "$post_urls_file" || true

    log "  ${cat} page ${page}: ${links_found} post links"

    # No more pages if we got 0 links
    if (( links_found == 0 )); then
      break
    fi

    (( page++ ))
  done
done

# De-duplicate post URLs
sort -u "$post_urls_file" -o "$post_urls_file"
total_posts=$(wc -l < "$post_urls_file")
log "Discovered ${total_posts} unique post URLs"

if $DRY_RUN; then
  log "Dry-run mode — post URLs:"
  cat "$post_urls_file"
  exit 0
fi

# ── Phase 2: Fetch each post page and extract video metadata ──────────────────

log "Phase 2 — Fetching ${total_posts} post pages (${CONCURRENT} concurrent) …"

metadata_file="$TMPDIR_SCRAPE/metadata.txt"
: > "$metadata_file"
errors_file="$TMPDIR_SCRAPE/errors.txt"
: > "$errors_file"
counter_file="$TMPDIR_SCRAPE/counter"
echo 0 > "$counter_file"
touch "$TMPDIR_SCRAPE/lock"

extract_metadata() {
  local post_url="$1"
  local html_file="$2"

  # Extract Schema.org VideoObject fields from <meta itemprop="..."> tags
  local content_url thumbnail_url duration upload_date category

  content_url=$(grep -oP 'itemprop="contentURL"\s+content="\K[^"]*' "$html_file" || true)
  thumbnail_url=$(grep -oP 'itemprop="thumbnailUrl"\s+content="\K[^"]*' "$html_file" || true)
  duration=$(grep -oP 'itemprop="duration"\s+content="\K[^"]*' "$html_file" || true)
  upload_date=$(grep -oP 'itemprop="uploadDate"\s+content="\K[^"]*' "$html_file" || true)
  category=$(grep -oP 'itemprop="name"\s+content="\K[^"]*' "$html_file" || true)

  if [[ -z "$content_url" ]]; then
    echo "$post_url" >> "$errors_file"
    return
  fi

  # Default values for missing fields
  : "${thumbnail_url:=}"
  : "${duration:=P0DT0H0M0S}"
  : "${upload_date:=}"
  : "${category:=Unknown}"

  # Output: VIDEO_URL|CATEGORY|SITE|THUMBNAIL_URL|DURATION|UPLOAD_DATE
  echo "${content_url}|${category}|Super Landia|${thumbnail_url}|${duration}|${upload_date}"
}

# Process posts with controlled parallelism
process_post() {
  set +e  # disable errexit in background workers
  local post_url="$1"
  local idx="$2"
  local post_html="$TMPDIR_SCRAPE/post_${idx}.html"

  if fetch "$post_url" "$post_html"; then
    local line
    line=$(extract_metadata "$post_url" "$post_html")
    if [[ -n "$line" ]]; then
      # Thread-safe append via flock
      flock "$TMPDIR_SCRAPE/lock" bash -c "cat >> '${metadata_file}'" <<< "$line"
    fi
  else
    flock "$TMPDIR_SCRAPE/lock" bash -c "cat >> '${errors_file}'" <<< "$post_url"
  fi

  # Progress counter
  local c
  c=$(flock "$counter_file" bash -c "c=\$(cat '${counter_file}'); c=\$((c+1)); echo \$c > '${counter_file}'; echo \$c")
  if (( c % 50 == 0 )); then
    log "  Progress: ${c} / ${total_posts}"
  fi
}

export -f process_post fetch extract_metadata log warn
export TMPDIR_SCRAPE metadata_file errors_file counter_file total_posts
export MAX_RETRIES RETRY_DELAY CURL_TIMEOUT

# Launch workers
idx=0
while IFS= read -r post_url; do
  process_post "$post_url" "$idx" &
  (( ++idx )) || true

  # Throttle: wait if we have $CONCURRENT background jobs
  while (( $(jobs -rp 2>/dev/null | wc -l) >= CONCURRENT )); do
    sleep 0.3
  done
done < "$post_urls_file"

# Wait for all remaining background jobs
wait || true

total_found=$(wc -l < "$metadata_file")
total_errors=$(wc -l < "$errors_file")
log "Extraction complete: ${total_found} videos found, ${total_errors} errors"

if (( total_errors > 0 )); then
  warn "Posts without video metadata:"
  cat "$errors_file" >&2
fi

# ── Phase 3: Write output files ──────────────────────────────────────────────

log "Phase 3 — Writing output files …"

# Sort metadata by category then upload date for consistency
sort -t'|' -k2,2 -k6,6 "$metadata_file" > "$TMPDIR_SCRAPE/metadata_sorted.txt"

# Backup existing files before overwriting
for f in video_urls.txt url_list.txt; do
  if [[ -f "${OUTPUT_DIR}/${f}" ]]; then
    cp "${OUTPUT_DIR}/${f}" "${OUTPUT_DIR}/${f}.bak"
    log "Backed up ${f} → ${f}.bak"
  fi
done

# video_urls.txt — full metadata (pipe-separated)
cp "$TMPDIR_SCRAPE/metadata_sorted.txt" "${OUTPUT_DIR}/video_urls.txt"

# url_list.txt — bare video URLs only
cut -d'|' -f1 "$TMPDIR_SCRAPE/metadata_sorted.txt" > "${OUTPUT_DIR}/url_list.txt"

video_count=$(wc -l < "${OUTPUT_DIR}/video_urls.txt")
url_count=$(wc -l < "${OUTPUT_DIR}/url_list.txt")

log "✅ Done!"
log "   video_urls.txt : ${video_count} entries"
log "   url_list.txt   : ${url_count} entries"

# ── Summary ──────────────────────────────────────────────────────────────────

echo ""
echo "══════════════════════════════════════════════════════════"
echo "  Scrape Summary"
echo "══════════════════════════════════════════════════════════"
echo "  Source       : ${SITE_URL}"
echo "  Categories   : ${CATEGORIES[*]}"
echo "  Posts found  : ${total_posts}"
echo "  Videos found : ${total_found}"
echo "  Errors       : ${total_errors}"
echo "  Output dir   : ${OUTPUT_DIR}"
echo "══════════════════════════════════════════════════════════"
