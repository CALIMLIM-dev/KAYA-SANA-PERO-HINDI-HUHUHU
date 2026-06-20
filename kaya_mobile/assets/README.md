# Assets Directory

This directory contains all static assets for the KAYA mobile app.

## Directory Structure

```
assets/
├── images/          # General images (backgrounds, placeholders, etc.)
├── icons/           # Custom icons and SVG files
├── logo/            # App logo and branding assets
└── fonts/           # Custom fonts (currently using Google Fonts)
```

## Usage

### Images
Place general images in the `images/` folder:
```dart
Image.asset('assets/images/logo.png')
```

### Icons
Place custom icons in the `icons/` folder:
```dart
SvgPicture.asset('assets/icons/custom_icon.svg')
```

### Logo
Place app logos in the `logo/` folder:
```dart
Image.asset('assets/logo/kaya_logo.png')
```

## Supported Formats

- **Images**: PNG, JPG, JPEG, GIF, WebP, BMP
- **Icons**: SVG, PNG
- **Fonts**: TTF, OTF (currently using Google Fonts)

## Optimization Tips

1. **Compress images** before adding them to reduce app size
2. **Use SVG** for icons when possible (scalable and smaller)
3. **Provide multiple resolutions** for raster images (1x, 2x, 3x)
4. **Use WebP format** for better compression

## Example Assets Needed

### Logo
- `kaya_logo.png` - Main app logo
- `kaya_logo_white.png` - White version for dark backgrounds
- `app_icon.png` - App launcher icon

### Images
- `splash_background.png` - Splash screen background
- `worker_placeholder.png` - Default worker avatar
- `empty_state.png` - Empty state illustrations

### Icons
- `category_cleaning.svg` - Cleaning category icon
- `category_plumbing.svg` - Plumbing category icon
- `category_electrical.svg` - Electrical category icon
- `verified_badge.svg` - Verified worker badge

## Notes

- Fonts are currently loaded via the `google_fonts` package
- No need to manually add font files
- All assets are referenced in `pubspec.yaml`
