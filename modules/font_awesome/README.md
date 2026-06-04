# Font Awesome module

Provides FontAwesome 7 Free icon glyphs merged into the ImGui font atlas so
icons can be used inline with text in any ImGui widget.

## Contents

| File | Description |
| --- | --- |
| `fa-solid-900.otf` | FontAwesome 7 Free — Solid style (filled icons) |
| `fa-regular-400.otf` | FontAwesome 7 Free — Regular style (outline icons) |
| `icons.json` | FA metadata: icon names, codepoints, available styles |
| `generate.py` | Generates `source/font_awesome.jai` from `icons.json` |

`source/font_awesome.jai` is auto-generated and vendored in the repo. The
Prizm build system (`first.jai`) regenerates it automatically when any of the
three source files (`icons.json`, `fa-solid-900.otf`, `fa-regular-400.otf`) is
newer than the generated file, provided Python is available. If Python is not
available, the vendored file is used as-is.

## Using icons

Icon constants follow the naming convention `ICON_FA_` + the icon name
uppercased with hyphens replaced by underscores.

To find an icon name:

- Browse the FA 7 icon gallery (filter to **Free** + **Solid**):
  https://fontawesome.com/icons?s=solid&o=r&m=free
- Take the icon name shown on the page (e.g. `circle-check`) and prefix with
  `ICON_FA_` uppercased: `ICON_FA_CIRCLE_CHECK`.

### Solid icons (filled)

The Solid font is merged into every ImGui font size at startup, so solid icons
are available in any widget with no extra setup:

```jai
ImGui.Button(ICON_FA_FOLDER_OPEN);
ImGui.Button(tprint("% Save", ICON_FA_FLOPPY_DISK));
```

### Regular icons (outline)

The Regular font is loaded as a separate font object per size. Push it before
the widget and pop it after to get outline-style icons:

```jai
ImGui.PushFont(app.font_set.fa_regular_normal);
ImGui.Button(ICON_FA_CIRCLE);
ImGui.PopFont();
```

The per-size fields are `fa_regular_small`, `fa_regular_normal`, `fa_regular_large`,
and `fa_regular_huge`, matching the `Font_Size` enum. They are also accessible as
the array `app.font_set.fa_regular[it_index]` when iterating over sizes.

Constants annotated `// S+R` in `source/font_awesome.jai` are available in both
styles; constants annotated `// S` are solid-only.

## Upgrading to a new FontAwesome version

1. Download the **FontAwesome Free desktop** release zip from:
   https://github.com/FortAwesome/Font-Awesome/releases

2. From the zip, replace the following files in `modules/font_awesome/`:
   - `metadata/icons.json` → `modules/font_awesome/icons.json`
   - `otfs/Font Awesome 7 Free-Solid-900.otf` → `modules/font_awesome/fa-solid-900.otf`
   - `otfs/Font Awesome 7 Free-Regular-400.otf` → `modules/font_awesome/fa-regular-400.otf`

3. Regenerate the Jai constants:
   ```
   python3 modules/font_awesome/generate.py modules/font_awesome/icons.json source/font_awesome.jai
   ```
   Or just run a normal build — `first.jai` will detect the newer files and
   call `generate.py` automatically.

4. Commit the updated `icons.json`, OTF files, and `source/font_awesome.jai`.

## License

FontAwesome Free fonts and icons are licensed under the
[SIL Open Font License 1.1](https://scripts.sil.org/OFL) (fonts) and
[Creative Commons BY 4.0](https://creativecommons.org/licenses/by/4.0/) (icons/SVGs).
See https://fontawesome.com/license/free for the full terms.
