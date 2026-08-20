#!/usr/bin/env bash
# Dumps the Postgres database to a timestamped, compressed custom-format
# archive. Custom format (-Fc) is required, not a convenience: it's the only
# pg_dump format pg_restore can use for selective/parallel restore, and it
# supports the --jobs flag that plain SQL dumps do not, which matters once
# the evidence/audit tables carrying 7-year retention data grow large.
#
# Usage: DATABASE_URL=postgresql://... ./backup-db.sh [output-dir]
set -euo pipefail

: "${DATABASE_URL:?Set DATABASE_URL, e.g. postgresql://postgres:postgres@127.0.0.1:54422/postgres}"
OUTPUT_DIR="${1:-./backups}"
mkdir -p "$OUTPUT_DIR"

TIMESTAMP=$(date -u +%Y%m%dT%H%M%SZ)
FILENAME="stericord-${TIMESTAMP}.dump"
OUTPUT_PATH="${OUTPUT_DIR}/${FILENAME}"

echo "Backing up $DATABASE_URL -> $OUTPUT_PATH"
pg_dump "$DATABASE_URL" -Fc -f "$OUTPUT_PATH"

SIZE=$(du -h "$OUTPUT_PATH" | cut -f1)
echo "Backup complete: $OUTPUT_PATH ($SIZE)"

# Fail loudly rather than leaving a silently-empty/corrupt archive on disk --
# a backup that can't be verified is worse than no backup, since it creates
# false confidence.
pg_restore --list "$OUTPUT_PATH" > /dev/null
echo "Archive verified readable by pg_restore."
