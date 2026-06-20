---
inclusion: always
---

# KAYA — Tech Stack & Conventions

## Mobile App (kaya_app)

- Flutter (Dart), Android + iOS targets
- State management: Provider (ChangeNotifier + Provider/Consumer/Selector). Do not introduce Bloc, Riverpod, or GetX.
- HTTP: `dio`, wrapped in a single ApiClient class
- Auth token storage: `flutter_secure_storage`
- Routing: centralized named routes (AppRoutes class)

## Backend API (kaya_api)

- Laravel (latest LTS), REST API only under `/api/v1/...`
- Auth: Laravel Sanctum (token-based) for the mobile app
- Database: MySQL, InnoDB, utf8mb4
- Every JSON response follows: `{ "success": bool, "data": ..., "message": string }`
- All tables: bigint auto-increment `id`, plus `created_at` / `updated_at`
- Foreign keys must have explicit `onDelete` behavior

## Admin Panel (kaya_api/admin)

- Inside the SAME Laravel project, Blade views, session-based auth using a separate `admin` guard (not Sanctum)
- Routes under `/admin/...`, protected by an `admin` middleware
- Styling: Tailwind via CDN, server-rendered, no SPA/build step

## Figma (via MCP)

- The connected Figma file is a CONTENT/LAYOUT reference only: what fields and sections exist on a screen.
- Do NOT copy Figma's colors, fonts, spacing, or component styling. Always apply `design-system.md` for the actual visual design.
