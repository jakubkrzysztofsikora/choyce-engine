# Choyce Cloud Service

Custom family-cloud backend for Choyce Engine.

## Stack
- FastAPI
- PostgreSQL (schema in `app/db/schema.sql`)
- Redis (recommended for session/queue cache)
- S3-compatible object storage (project snapshots/assets)

## Run (dev)
```bash
cd services/choyce-cloud
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8080
```

## API Surface
- `POST /v1/sessions/invites`
- `POST /v1/sessions/join`
- `POST /v1/sessions/{session_id}/close`
- `POST /v1/projects/sync`
- `GET /v1/projects/{project_id}`
- `GET /v1/catalog/list`
- `POST /v1/catalog/submit`
- `POST /v1/catalog/{listing_id}/review`
- `POST /v1/privacy/export`
- `POST /v1/privacy/delete`
- `POST /v1/privacy/retention`
- `GET /v1/privacy/jobs/{job_id}`
- `POST /v1/telemetry/events`
- `GET /v1/readmodels/kid-status/{profile_id}`
- `GET /v1/readmodels/parent-audit/{parent_id}`
- `GET /v1/readmodels/ai-performance`
