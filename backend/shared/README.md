# Backend Shared Core

Shared timetable data model, migrations, repositories, and services used by both Workers.

## Migrations

Apply migrations in lexical order from `backend/shared/migrations/`.

Local D1 examples:

```bash
pnpm --dir backend/worker-api d1:migrate:local
pnpm --dir backend/worker-admin d1:migrate:local
```

Both workers point at the same migration directory and should stay on the same schema version.
