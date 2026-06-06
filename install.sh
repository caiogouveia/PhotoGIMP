#!/usr/bin/env bash

set -e

# ── Colors ─────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_CONFIG="$SCRIPT_DIR/.config/GIMP/3.0"
DRY_RUN=false

usage() {
    echo "Usage: $0 [--dry-run]"
    echo ""
    echo "  --dry-run   Show what would be installed without making any changes."
}

for arg in "$@"; do
    case "$arg" in
        --dry-run|-n) DRY_RUN=true ;;
        --help|-h) usage; exit 0 ;;
        *) echo -e "${RED}✗${NC} Unknown option: $arg" >&2; usage; exit 1 ;;
    esac
done

info()    { echo -e "${BLUE}→${NC} $*"; }
success() { echo -e "${GREEN}✓${NC} $*"; }
warn()    { echo -e "${YELLOW}⚠${NC} $*"; }
die()     { echo -e "${RED}✗${NC} $*" >&2; exit 1; }

# Runs a command normally, or prints it in dry-run mode.
run() {
    if $DRY_RUN; then
        echo -e "  ${YELLOW}[dry-run]${NC} $*"
    else
        "$@"
    fi
}

echo ""
echo -e "${BOLD}╔══════════════════════════════════════╗${NC}"
echo -e "${BOLD}║        PhotoGIMP Installer           ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════╝${NC}"

if $DRY_RUN; then
    echo -e "  ${YELLOW}${BOLD}DRY-RUN MODE — no files will be changed${NC}"
fi
echo ""

# ── Check GIMP is not running ──────────────────────────────────────────────────
if pgrep -x "gimp" &>/dev/null || pgrep -xf "gimp-[0-9]" &>/dev/null || pgrep -f "org.gimp.GIMP" &>/dev/null; then
    die "GIMP is running. Close GIMP first, then run this installer.\n  (GIMP overwrites shortcutsrc and gimprc on exit, undoing the installation.)"
fi

# ── Detect OS ──────────────────────────────────────────────────────────────────
case "$(uname -s)" in
    Linux*)  OS="linux" ;;
    Darwin*) OS="macos" ;;
    *) die "Unsupported OS: $(uname -s). This installer supports Linux and macOS." ;;
esac

# ── Config base path ───────────────────────────────────────────────────────────
case "$OS" in
    linux) GIMP_CONFIG_BASE="$HOME/.config/GIMP" ;;
    macos) GIMP_CONFIG_BASE="$HOME/Library/Application Support/GIMP" ;;
esac

if [[ ! -d "$GIMP_CONFIG_BASE" ]]; then
    die "GIMP config folder not found at: $GIMP_CONFIG_BASE\n  Please install GIMP, open it once to generate its config, then run this installer."
fi

# ── Find installed GIMP version folders ────────────────────────────────────────
versions=()
while IFS= read -r dir; do
    [[ -d "$dir" ]] && versions+=("$(basename "$dir")")
done < <(find "$GIMP_CONFIG_BASE" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | LC_ALL=C sort)

if [[ ${#versions[@]} -eq 0 ]]; then
    die "No GIMP version folders found in: $GIMP_CONFIG_BASE\n  Please open GIMP at least once so it can create its config folder."
fi

# ── Version selection ──────────────────────────────────────────────────────────
echo "Found GIMP config folder(s) in: $GIMP_CONFIG_BASE"
echo ""

if [[ ${#versions[@]} -eq 1 ]]; then
    SELECTED_VERSION="${versions[0]}"
    info "Detected version: ${BOLD}${SELECTED_VERSION}${NC}"
    echo ""
else
    echo "Multiple GIMP versions detected. Select which one to install PhotoGIMP into:"
    echo ""
    PS3=$'\nEnter number: '
    select SELECTED_VERSION in "${versions[@]}"; do
        [[ -n "$SELECTED_VERSION" ]] && break
        warn "Invalid selection, please try again."
    done
    echo ""
fi

# ── Compatibility check ────────────────────────────────────────────────────────
MAJOR="${SELECTED_VERSION%%.*}"
if [[ "$MAJOR" =~ ^[0-9]+$ ]] && [[ "$MAJOR" -lt 3 ]]; then
    warn "PhotoGIMP requires GIMP 3.0 or newer."
    warn "Version '$SELECTED_VERSION' is not supported and may not work correctly."
    echo ""
    read -rp "Continue anyway? [y/N] " FORCE
    case "${FORCE,,}" in
        y|yes) echo "" ;;
        *) info "Installation cancelled."; exit 0 ;;
    esac
fi

TARGET_CONFIG="$GIMP_CONFIG_BASE/$SELECTED_VERSION"

# ── Installation summary ───────────────────────────────────────────────────────
echo -e "  ${BOLD}Installation summary${NC}"
echo "  ──────────────────────────────────────────"
printf "  %-18s %s\n" "Platform:"      "$OS"
printf "  %-18s %s\n" "GIMP version:"  "$SELECTED_VERSION"
printf "  %-18s %s\n" "Config target:" "$TARGET_CONFIG"
if [[ "$OS" == "linux" ]]; then
    printf "  %-18s %s\n" "Desktop entry:" "$HOME/.local/share/applications/"
    printf "  %-18s %s\n" "Icons:"         "$HOME/.local/share/icons/"
fi
echo ""

if $DRY_RUN; then
    warn "Dry-run: no changes will be made."
else
    warn "This will overwrite existing GIMP configuration files."
fi
echo ""

read -rp "Proceed? [y/N] " CONFIRM
case "${CONFIRM,,}" in
    y|yes) echo "" ;;
    *) info "Installation cancelled."; exit 0 ;;
esac

# ── Optional backup ────────────────────────────────────────────────────────────
read -rp "Create a backup of your current config before installing? [Y/n] " DO_BACKUP
case "${DO_BACKUP,,}" in
    n|no) echo "" ;;
    *)
        BACKUP_PATH="${GIMP_CONFIG_BASE}/${SELECTED_VERSION}_backup_$(date +%Y%m%d_%H%M%S)"
        info "Backing up to: $BACKUP_PATH"
        run cp -r "$TARGET_CONFIG" "$BACKUP_PATH"
        $DRY_RUN || success "Backup created."
        echo ""
        ;;
esac

# ── Install GIMP config files ──────────────────────────────────────────────────
info "Installing PhotoGIMP config files into: $TARGET_CONFIG"
# theme.css is auto-generated by GIMP on startup (it imports gimp.css automatically).
# We must NOT overwrite it or gimp.css will never be loaded.
run rsync -a --exclude='theme.css' "$SOURCE_CONFIG/." "$TARGET_CONFIG/"
run chmod +x "$TARGET_CONFIG/plug-ins/photogimp-opacity/photogimp-opacity.py"
run chmod +x "$TARGET_CONFIG/plug-ins/photogimp-channels/photogimp-channels.py"
$DRY_RUN || success "Config files installed."

# ── Install Linux-specific files ───────────────────────────────────────────────
if [[ "$OS" == "linux" ]]; then
    APPS_DIR="$HOME/.local/share/applications"
    ICONS_DIR="$HOME/.local/share/icons"

    info "Installing desktop entry..."
    run mkdir -p "$APPS_DIR"
    run cp "$SCRIPT_DIR/.local/share/applications/org.gimp.GIMP.desktop" "$APPS_DIR/"
    $DRY_RUN || success "Desktop entry installed."

    info "Installing icons..."
    run cp -r "$SCRIPT_DIR/.local/share/icons/." "$ICONS_DIR/"
    $DRY_RUN || success "Icons installed."

    if ! $DRY_RUN; then
        command -v update-desktop-database &>/dev/null \
            && update-desktop-database "$APPS_DIR" 2>/dev/null || true
        command -v gtk-update-icon-cache &>/dev/null \
            && gtk-update-icon-cache -f "$ICONS_DIR/hicolor" 2>/dev/null || true
    fi
fi

# ── Done ───────────────────────────────────────────────────────────────────────
echo ""
if $DRY_RUN; then
    echo -e "${YELLOW}${BOLD}Dry-run complete — no files were changed.${NC}"
    echo ""
    info "Run without --dry-run to perform the actual installation."
else
    echo -e "${GREEN}${BOLD}PhotoGIMP installed successfully!${NC}"
    echo ""
    info "Open GIMP to see your new Photoshop-like layout."
fi
echo ""
