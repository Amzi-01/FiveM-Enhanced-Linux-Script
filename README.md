# FiveM Enhanced Linux Script

Automated setup for **FiveM for GTA V Enhanced** on Linux using **Bottles (Flatpak)** + **GE-Proton**.
<img width="2952" height="1606" alt="image" src="https://github.com/user-attachments/assets/9f9a0c2b-f23b-42a6-aced-5b9271ad2d89" />

---

## ⚠️ Limitations — read this before anything else

- **This gets the LAUNCHER working, nothing more.** The WebView2/Chromium UI renders and you can
  browse the server list. That is the goal of this script.
- **You cannot join anti-cheat-protected servers.** Cfx.re does **not** support Linux. When you
  connect you will most likely get:
  > Requesting ticket failed. Error: Integrity check failure.

  That is FiveM's anti-cheat detecting a non-Windows environment.
- **No bypass is included, and none will be added.** This script contains **zero** anti-cheat or
  Wine-detection evasion. If you want anti-cheat multiplayer, use a **real Windows install**
  (dual-boot or a Windows PC). Single-player, development, and FXServer testing work fine here.
- **The official FiveM installer is not bundled.** You download `FiveM.exe` yourself from the
  official FiveM website; the script pauses and tells you where to put it. No download URL is
  hardcoded.
- **Not fully end-to-end tested.** Assembled from a working manual setup; the fresh-bottle path may
  need a one-time GUI step on some Bottles versions (the script tells you if so).
- **Bottles Flatpak only.** Paths assume the Flatpak layout of Bottles.

If those limitations are a dealbreaker, stop here — this script will not do what you want.

---

## What it actually does (all legitimate Wine compatibility setup)

1. Imports a recent **GE-Proton** runner (wine 10) into Bottles — older Wine can't run the
   WebView2/Chromium launcher UI (it dies on SIGSYS / RPC failures).
2. Installs the **Microsoft Edge WebView2 runtime** into the prefix and finishes the registration
   step the installer aborts under Wine.
3. Forces **`wininet=builtin`** — native `wininet` calls `iertutil.dll` ordinal 650, which Wine
   doesn't implement, and crashes.
4. Wires the launcher to the WebView2 runtime via env vars.
5. Creates a desktop launcher + icon.

## Requirements

- Flatpak, and Bottles: `flatpak install -y flathub com.usebottles.bottles` (launch it once first)
- `curl`, `tar`; recommended: `python3` + `python3-yaml`, ImageMagick (`magick`)
- ~1.5 GB free for the runtime, plus the FiveM/GTA download on top

## Usage

```bash
chmod +x install.sh
./install.sh
```

Re-running is safe — each step is skipped if it's already done. Override the bottle name with
`BOTTLE_NAME=MyName ./install.sh`. If `bottles-cli new` fails on your Bottles version, create the
bottle in the GUI (Gaming environment, GE-Proton runner) and re-run.

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| Black launcher window | WebView2 not found — re-run; ensure step 3 (WebView2) completed. |
| `unimplemented function iertutil.dll.650` | `wininet` reverted to native — confirm the `wininet=builtin` override. |
| `Requesting ticket failed / Integrity check failure` | **Expected.** Anti-cheat vs. Linux. Not fixable without a real Windows install. |
| Launcher UI cursor invisible | Known Wine + embedded-Chromium quirk; cosmetic. |

## Disclaimer

Provided as-is, no warranty ([MIT](LICENSE)). You are responsible for complying with the
FiveM / Cfx.re and Rockstar Games terms of service. Not affiliated with Cfx.re or Rockstar.
