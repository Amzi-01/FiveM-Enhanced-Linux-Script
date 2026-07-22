#!/usr/bin/env bash
#
# FiveM Enhanced Linux Script
# ---------------------------
# Sets up "FiveM for GTA V Enhanced" under Bottles (Flatpak) + GE-Proton,
# reproducing a working LAUNCHER on Linux.
#
# WHAT THIS DOES (all legitimate Wine compatibility setup):
#   1. Imports a recent GE-Proton runner into Bottles (wine 10 - runs the
#      WebView2/Chromium launcher UI, which older Wine cannot).
#   2. Installs the Microsoft Edge WebView2 runtime into the prefix and
#      finishes the registration that the installer aborts under Wine.
#   3. Forces wininet=builtin (native wininet crashes on iertutil.dll.650).
#   4. Points the launcher at the WebView2 runtime via env vars.
#   5. Creates a desktop launcher.
#
# ============================ HONEST LIMITATION ============================
# This gets the LAUNCHER working. It does NOT let you join anti-cheat servers.
# Cfx.re does not support Linux; when you connect you will likely get:
#     "Requesting ticket failed. Error: Integrity check failure."
# That is FiveM's anti-cheat detecting a non-Windows environment. This script
# deliberately contains NO anti-cheat / Wine-detection evasion. If you need
# anti-cheat multiplayer, use a real Windows install. Single-player, dev work,
# and FXServer testing are fine here.
# ==========================================================================
#
# License: MIT. Provided as-is, no warranty. You are responsible for complying
# with the FiveM / Cfx.re and Rockstar terms of service.

set -uo pipefail

# ---------------------------------------------------------------- config ----
BOTTLE_NAME="${BOTTLE_NAME:-FiveM-Enhanced}"
BOTTLES_DATA="$HOME/.var/app/com.usebottles.bottles/data/bottles"
RUNNERS_DIR="$BOTTLES_DATA/runners"
PREFIX="$BOTTLES_DATA/bottles/$BOTTLE_NAME"
WEBVIEW2_FWLINK="https://go.microsoft.com/fwlink/p/?LinkId=2124703"  # Evergreen bootstrapper
WORK="$HOME/.cache/fivem-enhanced-linux-script"

# ---------------------------------------------------------------- helpers ---
c_reset=$'\e[0m'; c_bold=$'\e[1m'; c_grn=$'\e[32m'; c_ylw=$'\e[33m'; c_red=$'\e[31m'; c_cyn=$'\e[36m'
say()  { printf '%s\n' "${c_cyn}==>${c_reset} $*"; }
ok()   { printf '%s\n' "${c_grn}  ok${c_reset} $*"; }
warn() { printf '%s\n' "${c_ylw}  !!${c_reset} $*"; }
die()  { printf '%s\n' "${c_red}error:${c_reset} $*" >&2; exit 1; }
in_bottle_bash() { flatpak run --command=bash com.usebottles.bottles -c "$1"; }

# --------------------------------------------------------------- preamble ---
cat <<'BANNER'
============================================================
 FiveM Enhanced Linux Script
 Gets the LAUNCHER working under Bottles + GE-Proton.
 Does NOT bypass anti-cheat. Anti-cheat servers will still
 reject the connection (Integrity check failure) - by design.
 Script Made By Amzi-01
============================================================
BANNER
read -r -p "Proceed? [y/N] " ans
[[ "${ans,,}" == "y" || "${ans,,}" == "yes" ]] || { echo "Aborted."; exit 0; }

mkdir -p "$WORK"

# ------------------------------------------------------- 0. prerequisites ---
say "Checking prerequisites"
command -v flatpak >/dev/null 2>&1 || die "flatpak is not installed. Install it via your distro first."
flatpak info com.usebottles.bottles >/dev/null 2>&1 \
  || die "Bottles is not installed. Run: flatpak install -y flathub com.usebottles.bottles"
command -v curl >/dev/null 2>&1 || die "curl is required."
ok "flatpak + Bottles + curl present"
[[ -d "$BOTTLES_DATA" ]] || die "Bottles data dir not found ($BOTTLES_DATA). Launch Bottles once, then re-run."

# --------------------------------------------------- 1. GE-Proton runner ----
say "Installing a GE-Proton runner (wine 10) into Bottles"
GEPROTON_DIR="$(find "$RUNNERS_DIR" -maxdepth 1 -type d -iname 'GE-Proton*' 2>/dev/null | sort -V | tail -1)"
if [[ -n "$GEPROTON_DIR" ]]; then
  ok "GE-Proton already present: $(basename "$GEPROTON_DIR")"
else
  say "Fetching latest GE-Proton release info from GitHub"
  TAG="$(curl -fsSL https://api.github.com/repos/GloriousEggroll/proton-ge-custom/releases/latest \
        | grep -oP '"tag_name":\s*"\K[^"]+' | head -1)"
  [[ -n "$TAG" ]] || die "Could not determine latest GE-Proton tag (rate-limited? try again later)."
  URL="https://github.com/GloriousEggroll/proton-ge-custom/releases/download/${TAG}/${TAG}.tar.gz"
  say "Downloading $TAG (~500 MB)"
  curl -fL --progress-bar -o "$WORK/geproton.tar.gz" "$URL" || die "GE-Proton download failed."
  mkdir -p "$RUNNERS_DIR"
  say "Extracting into Bottles runners"
  tar -xzf "$WORK/geproton.tar.gz" -C "$RUNNERS_DIR" || die "Extract failed."
  GEPROTON_DIR="$RUNNERS_DIR/$TAG"
  ok "Runner installed: $TAG"
fi
RUNNER_NAME="$(basename "$GEPROTON_DIR")"
WINE="$GEPROTON_DIR/files/bin/wine"
[[ -x "$WINE" ]] || die "wine binary not found in runner: $WINE"

# ----------------------------------------------------------- 2. bottle -----
say "Creating the Bottles prefix '$BOTTLE_NAME' (if needed)"
if [[ -f "$PREFIX/bottle.yml" ]]; then
  ok "Bottle already exists"
else
  flatpak run --command=bottles-cli com.usebottles.bottles new \
      --bottle-name "$BOTTLE_NAME" --environment gaming --runner "$RUNNER_NAME" \
      || warn "bottles-cli new returned nonzero - if the bottle wasn't created, make it in the Bottles GUI (Gaming env, runner $RUNNER_NAME) and re-run."
  [[ -f "$PREFIX/bottle.yml" ]] || die "Bottle not created. Create it in the Bottles GUI then re-run."
  ok "Bottle created"
fi

# Initialise / upgrade the prefix with this runner
say "Initialising prefix with $RUNNER_NAME (wineboot)"
in_bottle_bash "export WINEPREFIX='$PREFIX' WINEDEBUG=-all; '$WINE' wineboot -u >/dev/null 2>&1; true"
ok "Prefix ready"

# --------------------------------------------------------- 3. WebView2 -----
say "Installing Microsoft Edge WebView2 runtime"
if find "$PREFIX/drive_c/Program Files (x86)/Microsoft/EdgeWebView/Application" -iname msedgewebview2.exe 2>/dev/null | grep -q .; then
  ok "WebView2 already installed"
else
  curl -fL --progress-bar -A "Mozilla/5.0" -o "$WORK/MicrosoftEdgeWebview2Setup.exe" "$WEBVIEW2_FWLINK" \
    || die "WebView2 bootstrapper download failed."
  say "Running WebView2 installer inside the prefix (bootstrapper may report an error under Wine - expected)"
  in_bottle_bash "export WINEPREFIX='$PREFIX' WINEDEBUG=-all; '$WINE' '$WORK/MicrosoftEdgeWebview2Setup.exe' /silent /install; true"

  # The bootstrapper unpacks to EdgeCore but aborts before populating
  # EdgeWebView\Application and writing the registry. Finish both by hand.
  CORE="$(find "$PREFIX/drive_c/Program Files (x86)/Microsoft/EdgeCore" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | sort -V | tail -1)"
  [[ -n "$CORE" ]] || die "WebView2 did not unpack (EdgeCore missing). Check network / try again."
  VER="$(basename "$CORE")"
  APP="$PREFIX/drive_c/Program Files (x86)/Microsoft/EdgeWebView/Application/$VER"
  if [[ ! -f "$APP/msedgewebview2.exe" ]]; then
    say "Finishing install: copying runtime into EdgeWebView\\Application\\$VER"
    mkdir -p "$APP"; cp -a "$CORE/." "$APP/"
  fi
  say "Registering WebView2 version $VER"
  GUID="{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}"
  in_bottle_bash "export WINEPREFIX='$PREFIX' WINEDEBUG=-all
    for K in 'HKLM\\\\SOFTWARE\\\\WOW6432Node\\\\Microsoft\\\\EdgeUpdate\\\\Clients\\\\$GUID' \
             'HKLM\\\\SOFTWARE\\\\Microsoft\\\\EdgeUpdate\\\\Clients\\\\$GUID' \
             'HKCU\\\\SOFTWARE\\\\Microsoft\\\\EdgeUpdate\\\\Clients\\\\$GUID'; do
      '$WINE' reg add \"\$K\" /v pv /t REG_SZ /d '$VER' /f  >/dev/null 2>&1
      '$WINE' reg add \"\$K\" /v name /t REG_SZ /d 'Microsoft Edge WebView2 Runtime' /f >/dev/null 2>&1
    done; true"
  WEBVIEW2_VER="$VER"
  ok "WebView2 $VER installed and registered"
fi
# resolve installed version for env var below
WEBVIEW2_VER="${WEBVIEW2_VER:-$(basename "$(find "$PREFIX/drive_c/Program Files (x86)/Microsoft/EdgeWebView/Application" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | sort -V | tail -1)")}"
WEBVIEW2_WINPATH="C:\\Program Files (x86)\\Microsoft\\EdgeWebView\\Application\\$WEBVIEW2_VER"

# ----------------------------------------- 4. env vars + wininet=builtin ----
say "Applying environment overrides to the bottle"
PY="import yaml,sys
p='$PREFIX/bottle.yml'
d=yaml.safe_load(open(p))
d.setdefault('Environment_Variables',{})
d['Environment_Variables']['WEBVIEW2_BROWSER_EXECUTABLE_FOLDER']=r'$WEBVIEW2_WINPATH'
d['Environment_Variables']['WEBVIEW2_ADDITIONAL_BROWSER_ARGUMENTS']='--disable-gpu --no-sandbox --disable-gpu-compositing'
d.setdefault('DLL_Overrides',{})
d['DLL_Overrides']['wininet']='builtin'
yaml.safe_dump(d,open(p,'w'),default_flow_style=False)
print('bottle.yml updated')"
if command -v python3 >/dev/null 2>&1 && python3 -c "import yaml" 2>/dev/null; then
  python3 -c "$PY" && ok "env vars + wininet=builtin written to bottle.yml"
else
  warn "python3+pyyaml not found - set these manually in Bottles GUI:"
  warn "  Env vars: WEBVIEW2_BROWSER_EXECUTABLE_FOLDER=$WEBVIEW2_WINPATH"
  warn "            WEBVIEW2_ADDITIONAL_BROWSER_ARGUMENTS=--disable-gpu --no-sandbox --disable-gpu-compositing"
  warn "  DLL override: wininet = builtin"
fi
# also set wininet=builtin in the registry (belt and suspenders; env wins anyway)
in_bottle_bash "export WINEPREFIX='$PREFIX' WINEDEBUG=-all; '$WINE' reg add 'HKCU\\\\Software\\\\Wine\\\\DllOverrides' /v wininet /t REG_SZ /d builtin /f >/dev/null 2>&1; true"

# ------------------------------------------------------ 5. FiveM installer --
say "FiveM Enhanced client"
FIVEM_EXE="$(find "$PREFIX/drive_c/users" -iname 'FiveM.exe' -path '*FiveM for GTAV Enhanced*' 2>/dev/null | head -1)"
if [[ -n "$FIVEM_EXE" ]]; then
  ok "FiveM already installed: $FIVEM_EXE"
else
  warn "The official FiveM Enhanced installer is NOT bundled (get it yourself, from the"
  warn "official FiveM site only). Place the downloaded 'FiveM.exe' installer at:"
  warn "    $WORK/FiveMInstaller.exe"
  read -r -p "Press Enter once it's there (or Ctrl-C to stop and run the installer manually via Bottles)... "
  [[ -f "$WORK/FiveMInstaller.exe" ]] || die "Installer not found; run it via Bottles GUI instead, then re-run this script."
  say "Launching the FiveM installer inside the prefix - follow its on-screen steps"
  in_bottle_bash "export WINEPREFIX='$PREFIX' WINEDEBUG=-all WINEDLLOVERRIDES='wininet=builtin' \
    WEBVIEW2_BROWSER_EXECUTABLE_FOLDER='$WEBVIEW2_WINPATH' \
    WEBVIEW2_ADDITIONAL_BROWSER_ARGUMENTS='--disable-gpu --no-sandbox --disable-gpu-compositing'; \
    '$WINE' '$WORK/FiveMInstaller.exe'; true"
  FIVEM_EXE="$(find "$PREFIX/drive_c/users" -iname 'FiveM.exe' -path '*FiveM for GTAV Enhanced*' 2>/dev/null | head -1)"
  [[ -n "$FIVEM_EXE" ]] || die "FiveM.exe not found after install."
  ok "FiveM installed"
fi

# ------------------------------------------------------ 6. desktop entry ----
say "Creating desktop launcher"
BINDIR="$HOME/.local/bin"; ICODIR="$HOME/.local/share/icons"; APPDIR="$HOME/.local/share/applications"
mkdir -p "$BINDIR" "$ICODIR" "$APPDIR" "$HOME/Desktop"
LAUNCH="$BINDIR/fivem-enhanced-launch.sh"
cat > "$LAUNCH" <<EOF
#!/usr/bin/env bash
# Auto-generated by FiveM Enhanced Linux Script.
exec flatpak run --command=bash com.usebottles.bottles -c '
export WINEPREFIX="$PREFIX"
export WINEDEBUG=-all
export WINEDLLOVERRIDES="wininet=builtin"
export WEBVIEW2_BROWSER_EXECUTABLE_FOLDER="$WEBVIEW2_WINPATH"
export WEBVIEW2_ADDITIONAL_BROWSER_ARGUMENTS="--disable-gpu --no-sandbox --disable-gpu-compositing"
cd "\$(dirname "$FIVEM_EXE")"
exec "$WINE" "$FIVEM_EXE"
'
EOF
chmod +x "$LAUNCH"

# simple generated icon (no external assets)
if command -v magick >/dev/null 2>&1; then
  magick -size 256x256 xc:none -fill '#141414' -draw 'roundrectangle 8,8 248,248 40,40' \
    -fill '#F0A30A' -font DejaVu-Sans-Bold -pointsize 66 -gravity center -annotate +0-18 'FiveM' \
    -fill '#E8E8E8' -font DejaVu-Sans-Bold -pointsize 26 -gravity center -annotate +0+42 'ENHANCED' \
    "$ICODIR/fivem-enhanced.png" 2>/dev/null && ICON="$ICODIR/fivem-enhanced.png" || ICON="applications-games"
else
  ICON="applications-games"
fi

DESKTOP_ENTRY="[Desktop Entry]
Type=Application
Version=1.0
Name=FiveM Enhanced
GenericName=GTA V Enhanced Multiplayer
Comment=Launch FiveM for GTA V Enhanced (Bottles + GE-Proton)
Exec=$LAUNCH
Icon=$ICON
Terminal=false
Categories=Game;
StartupNotify=true"
printf '%s\n' "$DESKTOP_ENTRY" > "$HOME/Desktop/FiveM-Enhanced.desktop"
printf '%s\n' "$DESKTOP_ENTRY" > "$APPDIR/FiveM-Enhanced.desktop"
chmod +x "$HOME/Desktop/FiveM-Enhanced.desktop" "$APPDIR/FiveM-Enhanced.desktop"
command -v update-desktop-database >/dev/null 2>&1 && update-desktop-database "$APPDIR" 2>/dev/null
ok "Desktop launcher created (icon: $ICON)"

# ------------------------------------------------------------- done ---------
cat <<EOF

${c_grn}${c_bold}Done.${c_reset}
  Bottle : $BOTTLE_NAME
  Runner : $RUNNER_NAME
  WebView2: $WEBVIEW2_VER
  Launch : double-click "FiveM Enhanced" on your desktop, or run
           $LAUNCH

${c_ylw}Reminder:${c_reset} the launcher will work; joining anti-cheat servers will not
(Cfx.re doesn't support Linux). This script includes no anti-cheat evasion.
For anti-cheat multiplayer, use a real Windows install.
EOF
