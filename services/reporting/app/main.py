"""
SteriCord reporting service (master prompt section 7: "Python, WeasyPrint").

Renders compliance PDFs (equipment, cycle, incident, evidence sheet) from
data read under the calling user's own Supabase session -- see
supabase_client.py for why that's the entire authorization model here.
"""

import base64
import json
import os
import time
from collections import defaultdict, deque
from datetime import datetime, timezone
from pathlib import Path

from fastapi import FastAPI, Header, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import Response
from jinja2 import Environment, FileSystemLoader
from weasyprint import HTML

from .supabase_client import SupabaseClient

app = FastAPI(title="SteriCord Reporting Service")

allowed_origins = os.environ.get("REPORTING_ALLOWED_ORIGINS", "http://localhost:5173").split(",")
app.add_middleware(
    CORSMiddleware,
    allow_origins=allowed_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

templates = Environment(loader=FileSystemLoader(Path(__file__).parent / "templates"))


def get_token(authorization: str | None = Header(default=None)) -> str:
    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(status_code=401, detail="Missing bearer token")
    return authorization.split(" ", 1)[1]


# Rate limiting: report generation renders full PDFs via WeasyPrint, which is CPU-heavy,
# so it's the one endpoint class here worth throttling per user (section 43: "Rate limiting
# where appropriate"). Keyed by the JWT `sub` claim -- not signature-verified here, only used
# to bucket requests, since PostgREST re-verifies the token on every actual data call anyway,
# so a forged `sub` can at most confuse a rate-limit bucket, never bypass authorization.
# In-memory and per-process: correct for this single-instance service; a horizontally scaled
# deployment would need a shared store (e.g. Redis) instead.
RATE_LIMIT_MAX_REQUESTS = 30
RATE_LIMIT_WINDOW_SECONDS = 60
_request_log: dict[str, deque] = defaultdict(deque)


def _subject_from_token(token: str) -> str:
    try:
        payload_b64 = token.split(".")[1]
        padded = payload_b64 + "=" * (-len(payload_b64) % 4)
        payload = json.loads(base64.urlsafe_b64decode(padded))
        return payload.get("sub", "unknown")
    except Exception:
        return "unknown"


def enforce_rate_limit(token: str) -> None:
    subject = _subject_from_token(token)
    now = time.monotonic()
    window_start = now - RATE_LIMIT_WINDOW_SECONDS
    log = _request_log[subject]
    while log and log[0] < window_start:
        log.popleft()
    if len(log) >= RATE_LIMIT_MAX_REQUESTS:
        raise HTTPException(status_code=429, detail="Too many report requests, slow down")
    log.append(now)


def render_pdf(template_name: str, **context) -> bytes:
    template = templates.get_template(template_name)
    html = template.render(
        generated_at=datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC"),
        **context,
    )
    return HTML(string=html).write_pdf()


async def log_export(client: SupabaseClient, organization_id: str, entity_type: str, entity_id: str):
    await client.rpc(
        "log_audit_event",
        {
            "p_organization_id": organization_id,
            "p_event_type": "REPORT_EXPORTED",
            "p_entity_type": entity_type,
            "p_entity_id": entity_id,
            "p_previous_state": None,
            "p_new_state": {"format": "pdf"},
        },
    )


def pdf_response(pdf_bytes: bytes, filename: str) -> Response:
    return Response(
        content=pdf_bytes,
        media_type="application/pdf",
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
    )


@app.get("/health")
async def health():
    return {"status": "ok"}


@app.get("/reports/equipment/{equipment_id}")
async def equipment_report(equipment_id: str, authorization: str | None = Header(default=None)):
    token = get_token(authorization)
    enforce_rate_limit(token)
    client = SupabaseClient(token)
    user = await client.whoami()

    equipment = await client.select_one("equipment", {"id": f"eq.{equipment_id}"})
    status_events = await client.select(
        "equipment_status_events", {"equipment_id": f"eq.{equipment_id}"}, order="changed_at.desc"
    )
    cycles = await client.select(
        "sterilization_cycles", {"equipment_id": f"eq.{equipment_id}"}, order="created_at.desc"
    )
    org = await client.select_one("organizations", {"id": f"eq.{equipment['organization_id']}"})

    pdf = render_pdf(
        "equipment_report.html",
        title=f"Equipment Report - {equipment['equipment_code']}",
        organization_name=org["name"],
        generated_by=user.get("email", "unknown"),
        equipment=equipment,
        status_events=status_events,
        cycles=cycles,
    )
    await log_export(client, equipment["organization_id"], "equipment", equipment_id)
    return pdf_response(pdf, f"equipment-{equipment['equipment_code']}.pdf")


@app.get("/reports/cycle/{cycle_id}")
async def cycle_report(cycle_id: str, authorization: str | None = Header(default=None)):
    token = get_token(authorization)
    enforce_rate_limit(token)
    client = SupabaseClient(token)
    user = await client.whoami()

    cycle = await client.select_one("sterilization_cycles", {"id": f"eq.{cycle_id}"})
    equipment_rows = await client.select("equipment", {"id": f"eq.{cycle['equipment_id']}"})
    equipment = equipment_rows[0] if equipment_rows else None
    packs = await client.select(
        "instrument_packs", {"sterilization_cycle_id": f"eq.{cycle_id}"}, order="pack_code.asc"
    )
    evidence = await client.select(
        "evidence_files",
        {"entity_type": "eq.sterilization_cycle", "entity_id": f"eq.{cycle_id}"},
        order="captured_at.desc",
    )
    verifications = await client.select(
        "verifications",
        {"entity_type": "eq.sterilization_cycle", "entity_id": f"eq.{cycle_id}"},
        order="verified_at.desc",
    )
    audit_events = await client.select(
        "audit_events",
        {"entity_type": "eq.sterilization_cycle", "entity_id": f"eq.{cycle_id}"},
        order="occurred_at.asc",
    )
    org = await client.select_one("organizations", {"id": f"eq.{cycle['organization_id']}"})

    pdf = render_pdf(
        "cycle_report.html",
        title=f"Cycle Report - {cycle['cycle_number']}",
        organization_name=org["name"],
        generated_by=user.get("email", "unknown"),
        cycle=cycle,
        equipment=equipment,
        packs=packs,
        evidence=evidence,
        verifications=verifications,
        audit_events=audit_events,
    )
    await log_export(client, cycle["organization_id"], "sterilization_cycle", cycle_id)
    return pdf_response(pdf, f"cycle-{cycle['cycle_number']}.pdf")


@app.get("/reports/incident/{incident_id}")
async def incident_report(incident_id: str, authorization: str | None = Header(default=None)):
    token = get_token(authorization)
    enforce_rate_limit(token)
    client = SupabaseClient(token)
    user = await client.whoami()

    incident = await client.select_one("incidents", {"id": f"eq.{incident_id}"})
    quarantines = await client.select("quarantines", {"source_incident_id": f"eq.{incident_id}"})
    org = await client.select_one("organizations", {"id": f"eq.{incident['organization_id']}"})

    pdf = render_pdf(
        "incident_report.html",
        title="Incident Report",
        organization_name=org["name"],
        generated_by=user.get("email", "unknown"),
        incident=incident,
        quarantines=quarantines,
    )
    await log_export(client, incident["organization_id"], "incident", incident_id)
    return pdf_response(pdf, f"incident-{incident_id[:8]}.pdf")


@app.get("/reports/evidence/{evidence_file_id}")
async def evidence_sheet(evidence_file_id: str, authorization: str | None = Header(default=None)):
    token = get_token(authorization)
    enforce_rate_limit(token)
    client = SupabaseClient(token)
    user = await client.whoami()

    evidence = await client.select_one("evidence_files", {"id": f"eq.{evidence_file_id}"})
    ocr_rows = await client.select(
        "ocr_extractions", {"evidence_file_id": f"eq.{evidence_file_id}"}, order="created_at.desc"
    )
    ai_rows = await client.select(
        "ai_analyses", {"evidence_file_id": f"eq.{evidence_file_id}"}, order="created_at.desc"
    )
    org = await client.select_one("organizations", {"id": f"eq.{evidence['organization_id']}"})

    pdf = render_pdf(
        "evidence_sheet.html",
        title="Evidence Sheet",
        organization_name=org["name"],
        generated_by=user.get("email", "unknown"),
        evidence=evidence,
        ocr=ocr_rows[0] if ocr_rows else None,
        ai=ai_rows[0] if ai_rows else None,
    )
    await log_export(client, evidence["organization_id"], "evidence_file", evidence_file_id)
    return pdf_response(pdf, f"evidence-{evidence_file_id[:8]}.pdf")
