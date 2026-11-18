# M5 Sports Record / Evidence / Verification

Implemented endpoints and service entry points are in `router.py` and `service.py`.

- Performance CRUD: `GET /v1/me/performance`, `POST /v1/performance`, `GET/PATCH/DELETE /v1/performance/{public_id}`.
- M3 read contract: `read_metric_bests(user_id, sport_id=None)`.
- Event ingestion contract: `create_from_event(user_id, sport_id, results, event_id)`; idempotency key is event + athlete + metric.
- Achievements CRUD and media/document upload intents, confirmation and owner-only reads.
- Verification: athlete submit/list/detail/resubmit; admin list/decision.
- `verification_status`, `source`, endorsement and reviewer fields are server-owned.

## Run

From `backend/` install `requirements.txt`, create `.env` from `.env.example`, configure a Firebase Admin service account file outside Git, then run:

```bash
uvicorn main:app --reload
```

Swagger: `http://127.0.0.1:8000/docs`.

## Integration contracts / explicit gaps

1. Current upload adapter is local-development storage (`M5_LOCAL_STORAGE_DIR`). It is **not** a production signed MinIO/S3 upload implementation and does not run ClamAV, MPEG transcode, thumbnailing or moderation. Do not deploy it publicly until M5's storage pipeline is replaced by the project's private object-storage adapter and scanner.
2. `GET /documents/{id}/url` and document download are currently owner-only. M4's `AccessGrantService` must be integrated before certificate sharing to a coach/recruiter.
3. Public stats return verified records only; production public reads must additionally call M4 `authorize()` + `project()` before returning any viewer-visible athlete fields.
4. Metric validation reads M1 `sports.config.metrics` (or `performance_metrics`) if present. The exact sport-config metric schema must be agreed with M1; unknown sport/metric and unit/range mismatches are rejected when definitions exist.
5. Verification admin route requires `users.role == "admin"`. Real verification decisions must also invoke M1 `ProfileCacheService` for identity/sport profile targets; that cross-owner callback is intentionally not duplicated here.
6. `create_from_event` is an internal service function; M3's results ingestion job should call it, not write `performance_entries` directly.

Flutter adapter: `client/lib/features/performance/data/m5_repository.dart`; list-state screen shells: `client/lib/features/performance/presentation/`. M1 owns app router registration; do not edit `lib/app/` without coordinating with M1.
