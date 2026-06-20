---
inclusion: always
---

# KAYA — Design System (use this instead of Figma's visual styling)

This app should NOT look like a generic Material Design template. Apply the following consistently across every screen, both the Flutter app and the admin panel.

## Color Palette

- Primary (brand):   `#0B3D4C`  (deep teal-navy — trust)
- Primary Light:     `#145C73`
- Accent:            `#FF8A3D`  (warm amber — opportunity/CTA buttons)
- Success / Verified:`#2E9E5B`
- Warning:           `#E0A106`
- Danger / Reject:   `#D9534F`
- Neutral 900 (text):`#1A1A1A`
- Neutral 600:       `#5C5C5C`
- Neutral 200 (bg):  `#F2F4F5`
- Surface / Card:    `#FFFFFF`

## Typography

- Headings: "Plus Jakarta Sans" (via google_fonts package)
- Body text: "Inter"
- Scale: Display 28/Bold, H1 22/Bold, H2 18/SemiBold, Body 14/Regular, Caption 12/Regular

## Shape & Spacing

- Spacing grid: 4, 8, 12, 16, 24, 32 px
- Card corner radius: 16px
- Button corner radius: 12px (pill buttons for primary CTAs: 28px)
- Cards: subtle shadow (elevation 1-2), white surface on Neutral 200 bg

## Components

- Verification Badge: small teal checkmark chip next to name, label "Verified"
- Status badges (application status): pill-shaped, color-coded (pending = warning, accepted = success, rejected = danger, withdrawn = neutral)
- Primary CTA buttons: Accent color, white text, pill shape
- Secondary buttons: outlined, Primary color border/text
