# LARAVEL BEST PRACTICES (MANDATORY)

Follow Laravel best practices for all backend code.

## Reuse Existing

Before creating new ones, reuse existing:
- Form Requests
- Policies
- Services
- Models
- Resource Controllers

## Business Logic

- Do not duplicate business logic
- Avoid putting business logic inside Blade views
- Keep controllers thin, services fat
- Use Form Requests for validation
- Use Policies for authorization
