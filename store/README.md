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
