---
inclusion: always
---

# KAYA — Folder Structure

## kaya_app/ (Flutter)

```
lib/
├── core/
│   ├── constants/      (api endpoints, app constants)
│   ├── theme/          (app_theme.dart, colors, text styles)
│   ├── routes/         (app_routes.dart)
│   └── utils/
├── data/
│   ├── models/         (one file per entity: job_model.dart, user_model.dart, etc.)
│   ├── services/       (api_client.dart, auth_service.dart, job_service.dart, ...)
│   └── repositories/
├── providers/          (one ChangeNotifier per feature: auth_provider.dart, job_provider.dart, ...)
├── features/
│   ├── auth/
│   │   ├── screens/
│   │   └── widgets/
│   ├── worker_profile/
│   │   ├── screens/
│   │   └── widgets/
│   ├── employer/
│   │   ├── screens/
│   │   └── widgets/
│   ├── jobs/
│   │   ├── screens/
│   │   └── widgets/
│   ├── applications/
│   │   ├── screens/
│   │   └── widgets/
│   ├── messaging/
│   │   ├── screens/
│   │   └── widgets/
│   ├── reviews/
│   │   ├── screens/
│   │   └── widgets/
│   └── notifications/
│       ├── screens/
│       └── widgets/
├── shared/
│   └── widgets/        (buttons, cards, badges, app_bar, etc.)
└── main.dart
```

## kaya_api/ (Laravel)

```
app/
├── Http/
│   ├── Controllers/
│   │   ├── Api/
│   │   │   └── V1/...
│   │   └── Admin/...
│   └── Middleware/
├── Models/
└── ...

database/
├── migrations/
└── seeders/

routes/
├── api.php          (all under /api/v1)
└── admin.php        (loaded with /admin prefix)

resources/
└── views/
    └── admin/...
```
