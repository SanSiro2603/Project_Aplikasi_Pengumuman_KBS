# QA Smoke Test Matrix

## API / Backend
1. Publish payload valid -> `success=true`.
2. Payload missing fields -> HTTP 400.
3. `status != published` -> ignored response.
4. Retry path: mock 429/5xx -> attempt count naik sampai max 3.

## Database / Storage
1. Insert token non-UUID -> ditolak policy.
2. Insert token UUID -> sukses.
3. Upload image valid (`jpg/png/webp`) -> sukses.
4. Upload unsupported ext -> ditolak UI.

## Auth / Permission
1. User non-admin login ke admin page -> redirect `/home`.
2. User admin -> bisa CRUD.

## Notifications
1. Publish tanpa image -> notif text-only.
2. Publish dengan image -> notif membawa preview image.
3. Duplicate publish event -> idempotent skip.

## Observability
1. Paksa error login/save -> row masuk `app_errors`.
2. Publish -> row masuk `notification_dispatch_log`.

