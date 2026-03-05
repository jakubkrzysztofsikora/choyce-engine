from __future__ import annotations

from datetime import datetime, timezone
from typing import Any
from uuid import uuid4

from fastapi import FastAPI, HTTPException, Query
from pydantic import BaseModel, Field

app = FastAPI(title="Choyce Cloud API", version="0.1.0")


def now_iso() -> str:
    return datetime.now(tz=timezone.utc).isoformat()


sessions: dict[str, dict[str, Any]] = {}
invites: dict[str, dict[str, Any]] = {}
projects: dict[str, dict[str, Any]] = {}
catalog: dict[str, dict[str, Any]] = {}
privacy_jobs: dict[str, dict[str, Any]] = {}
telemetry_events: list[dict[str, Any]] = []
audit_events: list[dict[str, Any]] = []
publish_requests: dict[str, dict[str, Any]] = {}


class SessionInviteRequest(BaseModel):
    family_id: str
    host_profile_id: str
    world_id: str
    role_policy: dict[str, Any] = Field(default_factory=dict)
    expires_minutes: int = 30


class SessionJoinRequest(BaseModel):
    invite_code: str
    actor_profile_id: str
    actor_role: str


class SessionCloseRequest(BaseModel):
    actor_profile_id: str
    reason: str = ""


class ProjectSyncRequest(BaseModel):
    project_id: str
    owner_profile_id: str
    payload: dict[str, Any] = Field(default_factory=dict)


class CatalogSubmitRequest(BaseModel):
    project_id: str
    actor_profile_id: str
    metadata: dict[str, Any] = Field(default_factory=dict)


class CatalogReviewRequest(BaseModel):
    reviewer_profile_id: str
    approved: bool
    reason: str = ""


class PrivacyActionRequest(BaseModel):
    parent_profile_id: str
    subject_profile_id: str
    scope: dict[str, Any] = Field(default_factory=dict)


class RetentionRequest(BaseModel):
    parent_profile_id: str
    subject_profile_id: str
    policy: dict[str, Any] = Field(default_factory=dict)


class TelemetryEventRequest(BaseModel):
    event_type: str
    payload: dict[str, Any] = Field(default_factory=dict)
    profile_id: str | None = None


class PublishRequestPayload(BaseModel):
    request_id: str
    project_id: str
    world_id: str
    state: int
    visibility: int
    requester_id: str
    reviewer_id: str = ""
    moderation_results: list[dict[str, Any]] = Field(default_factory=list)
    rejection_reason: str = ""
    created_at: str = ""
    published_at: str = ""
    unpublished_at: str = ""
    revision_count: int = 0


@app.post("/v1/sessions/invites")
def create_invite(req: SessionInviteRequest) -> dict[str, Any]:
    invite_code = f"inv_{uuid4().hex[:12]}"
    session_id = f"sess_{uuid4().hex[:12]}"
    session = {
        "session_id": session_id,
        "family_id": req.family_id,
        "world_id": req.world_id,
        "host_profile_id": req.host_profile_id,
        "role_policy": req.role_policy,
        "status": "open",
        "members": [req.host_profile_id],
        "created_at": now_iso(),
    }
    sessions[session_id] = session
    invites[invite_code] = {
        "invite_code": invite_code,
        "session_id": session_id,
        "family_id": req.family_id,
        "expires_minutes": req.expires_minutes,
        "created_at": now_iso(),
    }
    return {"invite_code": invite_code, "session_id": session_id}


@app.post("/v1/sessions/join")
def join_session(req: SessionJoinRequest) -> dict[str, Any]:
    invite = invites.get(req.invite_code)
    if invite is None:
        raise HTTPException(status_code=404, detail="invite not found")
    session_id = str(invite["session_id"])
    session = sessions.get(session_id)
    if session is None or session.get("status") != "open":
        raise HTTPException(status_code=409, detail="session closed")

    if req.actor_profile_id not in session["members"]:
        session["members"].append(req.actor_profile_id)
    return {"session_id": session_id, "status": "joined", "members": session["members"]}


@app.post("/v1/sessions/{session_id}/close")
def close_session(session_id: str, req: SessionCloseRequest) -> dict[str, Any]:
    session = sessions.get(session_id)
    if session is None:
        raise HTTPException(status_code=404, detail="session not found")
    if req.actor_profile_id != session.get("host_profile_id"):
        raise HTTPException(status_code=403, detail="only host may close")
    session["status"] = "closed"
    session["closed_reason"] = req.reason
    session["closed_at"] = now_iso()
    return {"session_id": session_id, "status": "closed"}


@app.post("/v1/projects/sync")
def sync_project(req: ProjectSyncRequest) -> dict[str, Any]:
    projects[req.project_id] = {
        "project_id": req.project_id,
        "owner_profile_id": req.owner_profile_id,
        "payload": req.payload,
        "updated_at": now_iso(),
    }
    return {"project_id": req.project_id, "synced": True}


@app.post("/v1/publish/requests")
def save_publish_request(payload: PublishRequestPayload) -> dict[str, Any]:
    row = payload.model_dump()
    row["updated_at"] = now_iso()
    publish_requests[payload.request_id] = row
    return {"ok": True, "request_id": payload.request_id}


@app.get("/v1/publish/requests/{request_id}")
def get_publish_request(request_id: str) -> dict[str, Any]:
    row = publish_requests.get(request_id)
    if row is None:
        raise HTTPException(status_code=404, detail="publish request not found")
    return row


@app.get("/v1/publish/projects/{project_id}/requests")
def list_publish_requests_for_project(project_id: str) -> dict[str, Any]:
    rows = [r for r in publish_requests.values() if r.get("project_id") == project_id]
    return {"items": rows}


@app.get("/v1/publish/requests/published")
def list_published_requests() -> dict[str, Any]:
    rows = [r for r in publish_requests.values() if int(r.get("state", -1)) == 4]
    return {"items": rows}


@app.get("/v1/projects/{project_id}")
def get_project(project_id: str) -> dict[str, Any]:
    project = projects.get(project_id)
    if project is None:
        raise HTTPException(status_code=404, detail="project not found")
    return project


@app.get("/v1/catalog/list")
def list_catalog(
    visibility: str | None = Query(default=None),
    approval_state: str | None = Query(default=None),
    limit: int = Query(default=50, ge=1, le=200),
) -> dict[str, Any]:
    rows = list(catalog.values())
    if visibility:
        rows = [r for r in rows if r.get("visibility") == visibility]
    if approval_state:
        rows = [r for r in rows if r.get("approval_state") == approval_state]
    return {"items": rows[:limit]}


@app.post("/v1/catalog/submit")
def submit_catalog(req: CatalogSubmitRequest) -> dict[str, Any]:
    listing_id = f"cat_{uuid4().hex[:12]}"
    listing = {
        "listing_id": listing_id,
        "project_id": req.project_id,
        "actor_profile_id": req.actor_profile_id,
        "metadata": req.metadata,
        "approval_state": "pending_review",
        "visibility": "private",
        "created_at": now_iso(),
    }
    catalog[listing_id] = listing
    return listing


@app.post("/v1/catalog/{listing_id}/review")
def review_catalog(listing_id: str, req: CatalogReviewRequest) -> dict[str, Any]:
    listing = catalog.get(listing_id)
    if listing is None:
        raise HTTPException(status_code=404, detail="listing not found")
    listing["approval_state"] = "approved" if req.approved else "rejected"
    listing["reviewer_profile_id"] = req.reviewer_profile_id
    listing["review_reason"] = req.reason
    listing["reviewed_at"] = now_iso()
    if req.approved:
        listing["visibility"] = "family"
    return listing


@app.post("/v1/privacy/export")
def request_export(req: PrivacyActionRequest) -> dict[str, Any]:
    job_id = f"job_export_{uuid4().hex[:10]}"
    privacy_jobs[job_id] = {
        "job_id": job_id,
        "type": "export",
        "parent_profile_id": req.parent_profile_id,
        "subject_profile_id": req.subject_profile_id,
        "scope": req.scope,
        "status": "queued",
        "created_at": now_iso(),
    }
    return {"job_id": job_id, "status": "queued"}


@app.post("/v1/privacy/delete")
def request_delete(req: PrivacyActionRequest) -> dict[str, Any]:
    job_id = f"job_delete_{uuid4().hex[:10]}"
    privacy_jobs[job_id] = {
        "job_id": job_id,
        "type": "delete",
        "parent_profile_id": req.parent_profile_id,
        "subject_profile_id": req.subject_profile_id,
        "scope": req.scope,
        "status": "queued",
        "created_at": now_iso(),
    }
    return {"job_id": job_id, "status": "queued"}


@app.post("/v1/privacy/retention")
def update_retention(req: RetentionRequest) -> dict[str, Any]:
    job_id = f"job_retention_{uuid4().hex[:10]}"
    privacy_jobs[job_id] = {
        "job_id": job_id,
        "type": "retention_update",
        "parent_profile_id": req.parent_profile_id,
        "subject_profile_id": req.subject_profile_id,
        "policy": req.policy,
        "status": "applied",
        "created_at": now_iso(),
    }
    return {"job_id": job_id, "status": "applied"}


@app.get("/v1/privacy/jobs/{job_id}")
def get_privacy_job(job_id: str) -> dict[str, Any]:
    job = privacy_jobs.get(job_id)
    if job is None:
        raise HTTPException(status_code=404, detail="job not found")
    return job


@app.post("/v1/telemetry/events")
def ingest_telemetry(req: TelemetryEventRequest) -> dict[str, Any]:
    event = {
        "event_id": f"evt_{uuid4().hex[:12]}",
        "event_type": req.event_type,
        "payload": req.payload,
        "profile_id": req.profile_id,
        "timestamp": now_iso(),
    }
    telemetry_events.append(event)
    return {"event_id": event["event_id"], "accepted": True}


@app.get("/v1/readmodels/kid-status/{profile_id}")
def read_kid_status(profile_id: str) -> dict[str, Any]:
    return {
        "profile_id": profile_id,
        "recent_projects": [
            {"project_id": p["project_id"], "updated_at": p["updated_at"]}
            for p in list(projects.values())[:20]
        ],
    }


@app.get("/v1/readmodels/parent-audit/{parent_id}")
def read_parent_audit(parent_id: str, limit: int = Query(default=50, ge=1, le=200)) -> dict[str, Any]:
    rows = [e for e in audit_events if e.get("parent_id") == parent_id]
    return {"parent_id": parent_id, "events": rows[:limit]}


@app.get("/v1/readmodels/ai-performance")
def read_ai_performance() -> dict[str, Any]:
    return {
        "window": "7d",
        "total_requests": len(telemetry_events),
        "policy_gates_triggered": len([e for e in telemetry_events if e.get("event_type") == "policy_gate"]),
        "blocked_by_moderation": len(
            [e for e in telemetry_events if e.get("event_type") == "moderation_block"]
        ),
    }
