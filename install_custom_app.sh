#!/usr/bin/env bash
# Importa o app growatt_custom garantindo que o working tree local
# esteja IDÊNTICO ao remoto (main), sem commits locais.
# Ao final, faz clear-cache, clear-website-cache, migrate e restart.

set -euo pipefail
IFS=$'\n\t'

######################################
# ============ Helpers ==============
######################################
log()  { printf "\n\033[1;32m[OK]\033[0m %s\n"   "$*"; }
info() { printf "\n\033[1;34m[INFO]\033[0m %s\n" "$*"; }
warn() { printf "\n\033[1;33m[WARN]\033[0m %s\n" "$*"; }
err()  { printf "\n\033[1;31m[ERR]\033[0m %s\n"  "$*" >&2; }
need() { command -v "$1" >/dev/null 2>&1 || { err "Comando obrigatório não encontrado: $1"; exit 1; }; }

######################################
# ============ Config ===============
######################################
SITE="$1"             						  # site alvo
APP_NAME="$2"                       # nome do app
GIT_URL="$3"                        # URL do git
GIT_BRANCH="$4"                     # branch alvo
APPS_DIR="apps"                     # subpasta de apps dentro do bench
BENCH_DIR="~/frappe-bench"          # raiz do bench
BENCH_BIN="bench"                   # comando bench
START_TS="$(date +%s)"              # timestamp for backup identification

echo "Starting installation of $APP_NAME on $SITE..."

######################################
# ======== BACKUP PRÉ-IMPORT =========
######################################
BACKUP_DIR="$BENCH_DIR/sites/$SITE/private/backups"
mkdir -p "$BACKUP_DIR"

# pega o .sql/.sql.gz mais recente criado após um timestamp,
# olhando APENAS em ~/frappe-bench/sites/$SITE/private/backups
get_newest_db_backup_after() {
  local since_epoch="$1"
  local dir="$2"
  local newest="" newest_mtime=0 f mtime
  shopt -s nullglob
  for f in "$dir"/*.sql*; do
    mtime=$(stat -c %Y "$f" 2>/dev/null || stat -f %m "$f")
    if [[ "$mtime" -ge "$since_epoch" && "$mtime" -ge "$newest_mtime" ]]; then
      newest="$f"; newest_mtime="$mtime"
    fi
  done
  echo "$newest"
}

clean_backups_since() {
  local since_epoch="$1" dir="$2" f mtime
  shopt -s nullglob
  for f in "$dir"/*; do
    # mtime portável (GNU/BSD)
    mtime=$(stat -c %Y "$f" 2>/dev/null || stat -f %m "$f")
    if [[ "$mtime" -ge "$since_epoch" ]]; then
      rm -f -- "$f" || true
    fi
  done
  shopt -u nullglob
}

info "Generating backup pre-import…"
$BENCH_BIN --site "$SITE" backup

DB_BACKUP_FILE="$(get_newest_db_backup_after "$START_TS" "$BACKUP_DIR")"
if [[ -z "$DB_BACKUP_FILE" ]]; then
  err "Backup created was not found at: $BACKUP_DIR"
  exit 1
fi
log "Backup created: $DB_BACKUP_FILE"

restore_after_failure() {
  warn "App installation failed. Executing full cleanup…"

  info "Running uninstall-app to remove leftovers…"
  $BENCH_BIN --site "$SITE" uninstall-app "$APP_NAME" --yes || true

  info "Removing app from installed apps list (precaution)…"
  $BENCH_BIN --site "$SITE" remove-from-installed-apps "$APP_NAME" || true

  cd "$BENCH_DIR"

  info "Checking apps.txt…"
  APPS_FILE="sites/apps.txt"
  if grep -q "^$APP_NAME$" "$APPS_FILE"; then
    info "Removing $APP_NAME from $APPS_FILE"
    sed -i "/^$APP_NAME$/d" "$APPS_FILE"
  else
    log "$APP_NAME not found in $APPS_FILE, nothing to remove."
  fi

  info "Restoring database with the previously created backup…"
  if $BENCH_BIN --site "$SITE" --force restore "$DB_BACKUP_FILE" --mariadb-root-password "$MYSQL_ROOT_PASSWORD"; then
    info "Deleting backup used…"
    clean_backups_since "$START_TS" "$BACKUP_DIR"
  else
    err "Restoration FAILED. Keeping backup at: $DB_BACKUP_FILE"
    exit 1
  fi
}

######################################
# ========= Instalar o app ==========
######################################
cd "$BENCH_DIR"

APPS_TXT="$BENCH_DIR/sites/apps.txt"

info "Adding '$APP_NAME' into $APPS_TXT"
grep -qxF "$APP_NAME" "$APPS_TXT" || { 
    [ -s "$APPS_TXT" ] && [ -n "$(tail -c1 "$APPS_TXT")" ] && echo >> "$APPS_TXT"
    echo "$APP_NAME" >> "$APPS_TXT"
}

info "Getting $APP_NAME from $GIT_URL ($GIT_BRANCH)"
$BENCH_BIN get-app "$APP_NAME" "$GIT_URL" "$GIT_BRANCH"

info "Installing $APP_NAME in $SITE"
if ! $BENCH_BIN --site "$SITE" install-app "$APP_NAME"; then
  restore_after_failure
fi

######################################
# === Clear caches, migrate, restart
######################################
info "Clearing caches on $SITE…"
$BENCH_BIN --site "$SITE" clear-cache
$BENCH_BIN --site "$SITE" clear-website-cache

info "Running Migrations on $SITE…"
$BENCH_BIN --site "$SITE" migrate

info "Restarting bench processes…"
$BENCH_BIN restart

log "🎉 App $APP_NAME successfully installed in $SITE 🎉"