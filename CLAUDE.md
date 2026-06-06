# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Project Is

PhotoGIMP is a **configuration-only patch** for GIMP 3.0+. There is no build step, no source code to compile, and no test suite. The entire project is a set of GIMP configuration files that users copy into their GIMP config directory to make GIMP look and behave like Adobe Photoshop.

There is no programming language runtime involved. Changes are deployed by users extracting the repo as a zip into their home directory.

## Repository Structure

```
.config/GIMP/3.0/       ← All GIMP config files (the actual patch)
  shortcutsrc           ← Keyboard shortcuts mapped to Photoshop equivalents
  toolrc                ← Tool ordering and configuration
  sessionrc             ← Window layout and panel positions
  dockrc                ← Panel/dock configuration
  gimprc                ← General GIMP preferences
  contextrc             ← Active tool/color context
  theme.css             ← Minor UI theme overrides
  templaterc            ← Canvas templates
  splashes/             ← Custom splash screen image
  tool-options/         ← Per-tool option presets
  filters/              ← Filter settings
  plug-in-settings/     ← Plugin-specific settings

.local/share/
  applications/org.gimp.GIMP.desktop   ← Linux app launcher (renames app to "PhotoGIMP")
  icons/hicolor/*/apps/photogimp.png   ← Custom app icons at multiple resolutions

docs/                   ← README translations (README_it.md, README_pl.md, README_pt.md, README_ru.md)
screenshots/            ← Project screenshots for the README
```

## Key Files to Know

- **`shortcutsrc`**: The most frequently edited file. Uses GIMP's action-name syntax: `(action "action-name" "keybinding")`. Active shortcuts are uncommented; inactive ones are listed at the bottom with `#` prefixes. The file contains three sections: `# NEW` (shortcuts added vs GIMP defaults), `# CHANGED` (remapped from GIMP defaults), `# UNCHANGED` (kept as-is), and `# INACTIVE` (available actions without bindings).

- **`gimprc`**: Plain-text GIMP preferences. Each preference is on its own line as `(key value)`.

- **`org.gimp.GIMP.desktop`**: The Flatpak launch command is `Exec=/usr/bin/flatpak run --branch=stable --arch=x86_64 --command=gimp --file-forwarding org.gimp.GIMP @@u %U @@`.

## How to Test Changes

Since there's no automated testing, validation requires:
1. Having GIMP 3.0+ installed (Flatpak on Linux: `flatpak install flathub org.gimp.GIMP`)
2. Backing up existing config: `cp -r ~/.config/GIMP/3.0 ~/GIMP-3.0-backup`
3. Symlinking or copying the repo's `.config/GIMP/3.0/` into `~/.config/GIMP/3.0/`
4. Launching GIMP to verify the changes

For Flatpak, the config path is `~/.config/GIMP/3.0/` (same as native installs on Linux).

## Contributing Guidelines

- **Shortcut changes**: Edit `.config/GIMP/3.0/shortcutsrc`. Follow the existing section structure (NEW / CHANGED / UNCHANGED / INACTIVE). Shortcuts should match [Adobe Photoshop's official Windows keyboard shortcuts](https://helpx.adobe.com/photoshop/using/default-keyboard-shortcuts.html).
- **README translations**: Add `docs/README_xx.md` where `xx` is the ISO 639-1 language code, then link it from `README.md` under the Translations section.
- **Icons**: Icons are provided at 16×16, 32×32, 48×48, 64×64, 128×128, 256×256, and 512×512 pixels under `.local/share/icons/hicolor/`.

## EditorConfig

All files use UTF-8, LF line endings, 4-space indentation, with a final newline.
