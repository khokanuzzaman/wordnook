# Store & brand assets

| Path | What |
| --- | --- |
| `source/icon_master.png` | Master app icon art (the lamp-lit nook with a "W" tile). Every launcher icon is generated from it. |
| `source/feature_graphic_master.png` | Master Google Play feature graphic. |
| `source/screenshot_background_master.png` | Background for the Play Store screenshot frames. |
| `play/icon_512.png` | Play Console hi-res icon (512×512). |
| `play/feature_graphic_1024x500.png` | Play Console feature graphic (1024×500). |
| `play/screenshot_background_1080x1920.png` | Screenshot frame background. |

Masters were generated with ChatGPT image generation from Wordnook's own brief and palette.

Regenerate every icon (Android mipmaps, adaptive foreground, iOS AppIcon set, the in-app mark) and the store graphics:

```bash
pip install pillow
python3 tools/brand/generate_icons.py
```

## Play Store screenshots

Real app captures, framed on the brand background with a headline. Play's policy requires real screens, not mock UI.

1. On a phone or emulator, capture these 5 screens in order and save them as `store/raw/01.png` … `05.png` (the folder is gitignored):
   1. Daily mid-game (a couple of coloured rows)
   2. A finished Daily with the board and the Share button
   3. The "Keep going?" card
   4. Journey "WARM-UP 1 OF 3"
   5. The Statistics screen with a streak

   Capture each one with:

   ```bash
   adb exec-out screencap -p > store/raw/01.png
   ```

2. Run `python3 tools/brand/compose_screenshots.py`. It writes `store/play/screenshots/01..05.png` at 1080×1920.
3. Upload those files as the phone screenshots in Play Console.

Headlines live in `HEADLINES` in the script. Keep them true: the Daily has no pop-up ads, and rewarded ads are opt-in only.
