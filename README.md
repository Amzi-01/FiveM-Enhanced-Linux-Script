# FiveM Enhanced Linux Script

Automated setup for **FiveM for GTA V Enhanced** on Linux using **Bottles (Flatpak)** + **GE-Proton**.
<img width="2952" height="1606" alt="image" src="https://github.com/user-attachments/assets/9f9a0c2b-f23b-42a6-aced-5b9271ad2d89" />

> **This script only sets up the _environment_.** It prepares a Bottles prefix (GE-Proton runner,
> WebView2 runtime, and the required fixes) so your system is ready for FiveM Enhanced — **it does
> not install FiveM itself.** After the script finishes, you install FiveM yourself by running its
> installer from the **Bottles menu** (see [Installing FiveM](#installing-fivem-you-do-this-part)).

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
- **You install FiveM yourself.** The script sets up the environment only — FiveM is **not**
  bundled and no download URL is hardcoded. You download the official FiveM Enhanced installer and
  run it from the **Bottles menu** (see [Installing FiveM](#installing-fivem-you-do-this-part)).
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

## Installing FiveM (you do this part)

The script only prepares the environment. **Installing FiveM itself is a manual step you do through
Bottles:**

1. Download the official **FiveM for GTA V Enhanced** installer (`FiveM.exe`) from the official
   FiveM website — nowhere else.
2. Open **Bottles** and open the **FiveM-Enhanced** bottle.
3. In the bottle, use **"Run Executable…"** and select the `FiveM.exe` installer you downloaded.
4. Let it download and install the client, then close it.
5. Launch the game from the **FiveM Enhanced** desktop icon the script created.

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
