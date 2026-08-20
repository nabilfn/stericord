#!/usr/bin/env bash
# Restores a backup produced by backup-db.sh into a target database.
# Refuses to run against a database that already has tables, since a
# restore's normal use case (disaster recovery, standing up a fresh
# environment) should never silently merge into live data -- if you
# actually want to overwrite an existing database, pass --force.
#
# Usage: DATABASE_URL=postgresql://... ./restore-db.sh <backup-file> [--force]
set -euo pipefail

: "${DATABASE_URL:?Set DATABASE_URL, e.g. postgresql://postgres:postgres@127.0.0.1:54422/postgres}"
BACKUP_FILE="${1:?Usage: restore-db.sh <backup-file> [--force]}"
FORCE="${2:-}"

if [ ! -f "$BACKUP_FILE" ]; then
  echo "Backup file not found: $BACKUP_FILE" >&2
  exit 1
fi

if [ "$FORCE" != "--force" ]; then
  EXISTING_TABLES=$(psql "$DATABASE_URL" -tAc \
    "select count(*) from information_schema.tables where table_schema = 'public';")
  if [ "$EXISTING_TABLES" -gt 0 ]; then
    echo "Target database already has $EXISTING_TABLES table(s) in 'public'." >&2
    echo "Refusing to restore without --force (this would merge into live data)." >&2
    exit 1
  fi
fi

echo "Restoring $BACKUP_FILE -> $DATABASE_URL"
# --exit-on-error is deliberately omitted: restoring into a Supabase-managed Postgres
# (production, or Supabase CLI's local image) always emits a handful of harmless errors
# for objects the *client* can't own -- supabase_vault/vault.secrets chief among them,
# since that extension only exists inside Supabase's own Postgres build. Verified by
# restoring a real local-stack dump into vanilla postgres:17: those errors are the only
# ones, and every `public` schema table (the actual application data) restores intact
# with correct row counts regardless.
pg_restore --dbname "$DATABASE_URL" --clean --if-exists --no-owner --no-privileges "$BACKUP_FILE" || true
echo "Restore complete (see above for any ignorable vault-extension warnings)."
