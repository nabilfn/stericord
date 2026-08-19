# SteriCord — Updated Master Development Prompt

> Use this prompt with an AI coding assistant in VS Code/Cursor/Claude Code/Codex to build SteriCord incrementally from foundation to hospital-pilot readiness.
>
> **Important:** AI is a mandatory part of SteriCord, but it must **not** be implemented before the core CSSD and OT traceability workflows are functional. Build the operational system first, then integrate OpenCV, OCR, and multimodal AI in the later phases below.

---

## 1. Role

You are a senior software architect, full-stack engineer, mobile engineer, healthcare software engineer, and DevOps engineer responsible for building **SteriCord**.

Your responsibilities are to:

- design the system architecture;
- create maintainable production-oriented code;
- build the Flutter mobile application;
- build the React web dashboard;
- build and secure the backend;
- design the PostgreSQL database;
- implement storage abstraction;
- implement sterilization traceability workflows;
- implement OT point-of-use safety workflows;
- implement audit trails;
- later integrate image quality checks, OCR, and multimodal AI;
- prepare the system for controlled hospital pilot deployment.

Build SteriCord **phase by phase**. Test each phase before continuing.

---

## 2. Product Purpose

SteriCord is a hospital sterilization traceability and assurance platform.

It digitizes:

```text
CSSD qualification
        ↓
Sterilization cycle
        ↓
Instrument pack
        ↓
Evidence capture
        ↓
Human verification
        ↓
Pack release
        ↓
OT / Ward point-of-use verification
        ↓
Incident / quarantine if failure occurs
        ↓
Audit trail
        ↓
Compliance reporting
```

It is intended to reduce reliance on:

- fading autoclave thermal receipts;
- loose indicator strips;
- physical logbooks;
- fragmented paper evidence;
- disconnected CSSD and OT records;
- slow incident escalation;
- difficult historical audit retrieval.

---

## 3. Core Principle

SteriCord is primarily a:

```text
Traceability
+ Evidence
+ Verification
+ Safety
+ Audit
+ Compliance
```

platform.

AI enhances the workflow. AI does **not** replace authorized healthcare professionals.

The system must preserve:

```text
WHO
did WHAT
to WHICH item
using WHICH equipment
WHEN
with WHAT evidence
WHAT the result was
WHO verified it
and WHAT happened afterward
```

---

## 4. Human-in-the-Loop AI

Use this architecture:

```text
Physical sterilization process
        ↓
SteriCord captures evidence
        ↓
Computer vision / OCR assists interpretation
        ↓
AI generates recommendation
        ↓
Confidence is recorded
        ↓
Authorized human verifies
        ↓
Final authoritative result
        ↓
Rules engine handles alerts / quarantine
        ↓
Immutable audit evidence retained
```

Never implement:

```text
AI → automatically declares sterile → releases pack
```

Supported AI states:

```text
PASS
FAIL
UNDETERMINED
```

`UNDETERMINED` must always require manual review.

---

## 5. Development Order

Follow this order:

1. **Phase 1 — Foundation**
2. **Phase 2 — CSSD Core**
3. **Phase 3 — OT Point-of-Use Safety**
4. **Phase 4 — Image Quality / OpenCV**
5. **Phase 5 — OCR / Document AI**
6. **Phase 6 — Multimodal AI / Gemini**
7. **Phase 7 — Compliance & Reporting**
8. **Phase 8 — Offline, Security & Pilot Hardening**

### Critical Instruction

Do **not** skip directly to AI.

Complete Phases 1–3 first.

After the CSSD and OT workflows are functional, AI integration becomes a mandatory part of the remaining roadmap.

---

## 6. First Working MVP

The first working version must support:

```text
Login
 ↓
Register Equipment
 ↓
Create Sterilization Cycle
 ↓
Register Instrument Pack
 ↓
Generate QR
 ↓
Capture Evidence
 ↓
Manual Verification
 ↓
Release Pack
 ↓
Scan Pack at OT / Ward
 ↓
Capture Internal Indicator
 ↓
Manual PASS / FAIL
 ↓
PASS → Complete record

FAIL
 ├── Alert CSSD
 ├── Quarantine affected pack / cycle
 ├── Create incident
 └── Preserve audit trail
```

Then add:

```text
OpenCV
 ↓
OCR
 ↓
Gemini / Multimodal AI
 ↓
Confidence Engine
 ↓
Human Verification
```

---

## 7. Technology Stack

### Mobile

```text
Flutter
Dart
```

Purpose:

- CSSD technician app;
- OT nurse app;
- QR scanning;
- camera capture;
- image preview;
- point-of-use verification;
- alerts;
- offline workflow later.

### Web Dashboard

```text
React
TypeScript
Vite
Tailwind CSS
shadcn/ui or equivalent
Lucide Icons
```

Purpose:

- hospital administration;
- CSSD supervisor dashboard;
- equipment management;
- cycle monitoring;
- pack monitoring;
- incidents;
- quarantine;
- reports;
- audit trail;
- user management.

### Backend

Use initially:

```text
Supabase
PostgreSQL
Supabase Auth
Supabase Realtime
Supabase Edge Functions
Row-Level Security
```

### Storage

Use a provider abstraction.

Potential providers:

```text
Supabase Storage
AWS S3 Malaysia
TM Cloud Object Storage
Azure Blob Storage
MinIO / Private Hospital Storage
```

MVP may use Supabase Storage temporarily.

### AI / Vision

Later phases:

```text
OpenCV
Google Document AI
Gemini multimodal model
Future SteriCord Vision Engine
```

### Reporting

```text
Python
WeasyPrint
```

### Future Hospital Integration

Prepare for:

```text
HL7
FHIR
Mirth Connect
Hospital HIS APIs
```

Do not prioritize these during the initial MVP.

---

## 8. Flutter and React Relationship

Flutter and React are two separate frontends connected to the **same backend**.

They do not communicate directly.

```text
Flutter Mobile
CSSD / OT Staff
      │
      ▼
Shared Backend
Supabase / API / PostgreSQL / Auth / Realtime
      ▲
      │
React Web
Admin / Supervisor
```

Example:

```text
OT Nurse marks indicator FAIL in Flutter
        ↓
Backend records failure
        ↓
Incident created
        ↓
Pack quarantined
        ↓
Realtime notification created
        ↓
React supervisor dashboard receives alert
```

There must be **one backend and one source of truth**.

Do not create separate databases for Flutter and React.

---

## 9. Monorepo Structure

```text
stericord/
│
├── apps/
│   ├── mobile/
│   │   ├── android/
│   │   ├── ios/
│   │   ├── lib/
│   │   │   ├── core/
│   │   │   ├── features/
│   │   │   ├── routes/
│   │   │   └── main.dart
│   │   ├── test/
│   │   └── pubspec.yaml
│   │
│   └── web/
│       ├── src/
│       │   ├── components/
│       │   ├── features/
│       │   ├── hooks/
│       │   ├── contexts/
│       │   ├── routes/
│       │   ├── services/
│       │   ├── types/
│       │   ├── utils/
│       │   ├── App.tsx
│       │   └── main.tsx
│       ├── package.json
│       └── vite.config.ts
│
├── supabase/
│   ├── migrations/
│   ├── functions/
│   ├── seed.sql
│   └── config.toml
│
├── services/
│   ├── ai/
│   ├── ocr/
│   ├── reporting/
│   └── notifications/
│
├── packages/
│   └── contracts/
│       └── openapi.yaml
│
├── infrastructure/
│   ├── docker/
│   ├── storage/
│   └── deployment/
│
├── docs/
│   ├── architecture/
│   ├── database/
│   ├── api/
│   ├── workflows/
│   └── validation/
│
├── .env.example
├── .gitignore
├── docker-compose.yml
└── README.md
```

---

## 10. Flutter Structure

```text
apps/mobile/lib/
│
├── core/
│   ├── config/
│   ├── constants/
│   ├── errors/
│   ├── network/
│   ├── storage/
│   └── theme/
│
├── features/
│   ├── auth/
│   ├── dashboard/
│   ├── equipment/
│   ├── cycles/
│   ├── packs/
│   ├── capture/
│   ├── verification/
│   ├── ot/
│   ├── incidents/
│   └── notifications/
│
├── routes/
└── main.dart
```

---

## 11. React Structure

```text
apps/web/src/
│
├── components/
│   ├── ui/
│   ├── layout/
│   └── common/
│
├── features/
│   ├── auth/
│   ├── dashboard/
│   ├── equipment/
│   ├── cycles/
│   ├── packs/
│   ├── incidents/
│   ├── quarantine/
│   ├── reports/
│   ├── audit/
│   └── users/
│
├── services/
├── hooks/
├── contexts/
├── routes/
├── types/
├── utils/
├── App.tsx
└── main.tsx
```

---

## 12. Shared Contracts

Flutter uses Dart. React uses TypeScript.

Do not attempt to directly share TypeScript UI/model source with Flutter.

Use language-independent contracts:

```text
OpenAPI
JSON Schema
API contracts
database schema
```

Store under:

```text
packages/contracts/
```

Example:

```text
packages/contracts/openapi.yaml
```

---

## 13. Environments

Support:

```text
Development
Staging
Production
```

Create `.env.example`.

Potential variables:

```env
SUPABASE_URL=
SUPABASE_ANON_KEY=
SUPABASE_SERVICE_ROLE_KEY=

STORAGE_PROVIDER=

AWS_REGION=
AWS_BUCKET=

TM_STORAGE_ENDPOINT=
TM_STORAGE_BUCKET=

GOOGLE_CLOUD_PROJECT_ID=
DOCUMENT_AI_PROCESSOR_ID=

GEMINI_API_KEY=
```

Never commit real credentials.

---

## 14. Multi-Tenancy

SteriCord must support multiple hospitals from day one.

```text
SteriCord
 │
 ├── Hospital A
 │    ├── Departments
 │    ├── Users
 │    ├── Equipment
 │    ├── Cycles
 │    └── Packs
 │
 ├── Hospital B
 └── Hospital C
```

Operational records should contain `organization_id` where appropriate.

Use PostgreSQL Row-Level Security.

Hospital A must never access Hospital B data.

---

## 15. Roles

Implement initially:

```text
SYSTEM_ADMIN
HOSPITAL_ADMIN
CSSD_SUPERVISOR
CSSD_TECHNICIAN
OT_NURSE
```

Prepare for:

```text
INFECTION_CONTROL
AUDITOR
BIOMEDICAL_ENGINEER
QUALITY_MANAGER
```

Authorization must be enforced at:

```text
UI
+
API / Edge Functions
+
Database / RLS
```

---

## 16. Core Database Domains

Create:

```text
organizations
departments
profiles
user_roles

equipment
equipment_status_events

sterilization_cycles
cycle_parameters

instrument_sets
instrument_packs

evidence_files
verifications

point_of_use_records

incidents
quarantines
notifications

audit_events
```

---

## 17. Equipment

Create `equipment`.

Suggested fields:

```text
id
organization_id
equipment_code
equipment_type
manufacturer
model_name
serial_number
location
operating_status
created_at
updated_at
```

Statuses:

```text
ACTIVE
LOCKED_OUT
MAINTENANCE
DECOMMISSIONED
```

Also create `equipment_status_events`.

Do not erase status history.

---

## 18. Sterilization Cycles

Create `sterilization_cycles`.

One cycle may contain many packs.

Suggested fields:

```text
id
organization_id
equipment_id
cycle_number
cycle_type
started_at
completed_at
temperature
pressure
hold_time_seconds
operator_user_id
cycle_status
created_at
updated_at
```

Statuses:

```text
CREATED
RUNNING
COMPLETED
PENDING_VERIFICATION
PASSED
FAILED
QUARANTINED
```

---

## 19. Instrument Sets

Create `instrument_sets`.

Examples:

```text
Major Ortho Tray
Minor Surgery Set
Caesarean Set
Laparoscopy Set
```

---

## 20. Instrument Packs

Create `instrument_packs`.

Suggested fields:

```text
id
organization_id
instrument_set_id
sterilization_cycle_id
pack_code
qr_code
packed_at
sterilized_at
expiry_date
status
created_by
created_at
updated_at
```

Statuses:

```text
PACKED
STERILIZING
PENDING_VERIFICATION
RELEASED
QUARANTINED
RECALLED
USED
EXPIRED
```

QR codes must use opaque identifiers.

---

## 21. Evidence

Create `evidence_files`.

Do not store large binaries directly in PostgreSQL.

Suggested metadata:

```text
id
organization_id
entity_type
entity_id
storage_provider
bucket
object_path
file_type
mime_type
file_size
sha256_hash
evidence_type
captured_by
captured_at
created_at
```

Evidence types:

```text
AUTOCLAVE_RECEIPT
BOWIE_DICK
BI_TRAY
CHEMICAL_INDICATOR
OT_INDICATOR
WASHER_TEST
GENERAL
```

---

## 22. Storage Provider Abstraction

Create an interface similar to:

```typescript
interface StorageProvider {
  uploadEvidence(...): Promise<unknown>;
  getEvidence(...): Promise<unknown>;
  generateSignedUrl(...): Promise<string>;
  archiveEvidence(...): Promise<unknown>;
  deleteExpiredEvidence(...): Promise<void>;
  calculateHash(...): Promise<string>;
}
```

Future implementations:

```text
SupabaseStorageProvider
AWSStorageProvider
TMCloudStorageProvider
AzureStorageProvider
MinIOStorageProvider
```

---

## 23. Retention

Design for:

```text
Maximum retention: 7 years
```

Internal base assumption:

```text
100 primary records
per hospital
per day
```

Do not make this an application limit.

Architecture target:

```text
1,000+ records/day/hospital
```

Stress target:

```text
10,000 records/day/hospital
```

Lifecycle concept:

```text
0–90 days
HOT

90 days–1 year
INFREQUENT ACCESS

1–7 years
ARCHIVE

After retention expiry
policy-controlled deletion
```

---

## 24. Verifications

Create `verifications`.

Keep AI predictions separate from the authoritative human result.

Suggested fields:

```text
id
organization_id
entity_type
entity_id
verification_type
ai_suggested_result
ai_confidence
human_result
verified_by
verified_at
notes
created_at
```

Results:

```text
PASS
FAIL
UNDETERMINED
```

---

## 25. Point-of-Use Records

Create `point_of_use_records`.

Workflow:

```text
Scan QR
 ↓
Retrieve pack
 ↓
Check eligibility
 ↓
Capture Type 4 / Type 5 indicator
 ↓
Analyze / manually verify
 ↓
PASS / FAIL
```

Prefer external patient / encounter references.

Avoid unnecessary patient demographics.

---

## 26. Incidents

Create `incidents`.

State machine:

```text
DETECTED
ALERTED
ACKNOWLEDGED
REPLACEMENT_DISPATCHED
REPLACEMENT_RECEIVED
QUARANTINE_IN_PROGRESS
NCR_OPEN
RESOLVED
CLOSED
```

Do not reduce incident handling to a single boolean.

---

## 27. Quarantine

Create `quarantines`.

Support scopes:

```text
PACK
CYCLE
BATCH
EQUIPMENT_RELATED_GROUP
```

Suggested fields:

```text
id
organization_id
source_incident_id
scope_type
scope_id
reason
status
initiated_by
initiated_at
released_by
released_at
release_reason
```

---

## 28. Notifications

Create `notifications`.

Initial channels:

```text
IN_APP
REALTIME
```

Future:

```text
EMAIL
SMS
PUSH
HOSPITAL_PAGER
```

Priority:

```text
LOW
MEDIUM
HIGH
CRITICAL
```

---

## 29. Audit Trail

Create `audit_events`.

Important events include:

```text
USER_LOGIN
EQUIPMENT_CREATED
EQUIPMENT_LOCKED
CYCLE_CREATED
CYCLE_VERIFIED
PACK_CREATED
PACK_RELEASED
PACK_SCANNED
OT_VERIFICATION_COMPLETED
INCIDENT_CREATED
QUARANTINE_STARTED
QUARANTINE_RELEASED
REPORT_EXPORTED
```

Suggested fields:

```text
id
organization_id
actor_user_id
event_type
entity_type
entity_id
previous_state
new_state
timestamp
session_id
device_id
metadata
event_hash
previous_event_hash
```

Critical historical events must not be silently overwritten.

---

## 30. Phase 1 — Foundation

Build:

```text
Authentication
Organizations
Departments
Profiles
Roles
Multi-tenancy
RLS
Equipment
Dashboard shell
```

Web screens:

```text
/login
/dashboard
/equipment
/equipment/:id
/users
/settings
```

Mobile screens:

```text
Login
Dashboard
Equipment List
Equipment Detail
Profile
```

### Phase 1 rule

Do not implement production AI in this phase.

AI remains mandatory later.

---

## 31. Phase 2 — CSSD Core

Build:

```text
Sterilization cycles
Instrument sets
Instrument packs
QR generation
Evidence capture
Manual verification
Pack release
```

Workflow:

```text
Create Cycle
 ↓
Select Equipment
 ↓
Enter Cycle Information
 ↓
Register Packs
 ↓
Capture Receipt / Evidence
 ↓
Manual Verification
 ↓
Release Cycle / Packs
```

---

## 32. Phase 3 — OT Point-of-Use Safety

Build:

```text
QR scanning
Pack lookup
Eligibility check
Indicator capture
Manual verification
PASS workflow
FAIL workflow
Alerts
Incidents
Quarantine
```

After this phase is stable, begin mandatory AI integration.

---

## 33. Phase 4 — Image Quality / OpenCV

Integrate:

```text
Blur detection
Exposure checks
Glare checks where practical
Perspective correction
Framing assistance
Image normalization
```

Do not rely on one universal hard-coded blur threshold.

Possible results:

```text
ACCEPTED
RETAKE_REQUIRED
```

Reasons:

```text
IMAGE_TOO_BLURRY
IMAGE_TOO_DARK
GLARE_DETECTED
INDICATOR_NOT_IN_FRAME
```

---

## 34. Phase 5 — OCR / Document AI

Integrate Google Document AI for autoclave thermal receipts.

Pipeline:

```text
Camera Capture
 ↓
OpenCV Preprocessing
 ↓
Document AI OCR
 ↓
Structured Extraction
 ↓
Human Confirmation
```

Extract where available:

```text
cycle number
temperature
pressure
hold duration
date
time
machine identifier
result
```

Do not make OCR output authoritative without review.

---

## 35. Phase 6 — Multimodal AI

AI is mandatory from this phase onward.

Create:

```text
AIProvider
```

Example:

```typescript
interface AIProvider {
  analyzeEvidence(...): Promise<AIAnalysisResult>;
}
```

Return structured output such as:

```json
{
  "analysis_status": "COMPLETED",
  "indicator_type": "BOWIE_DICK",
  "suggested_result": "PASS",
  "confidence": 0.94,
  "observations": [
    "Uniform visual transition detected"
  ]
}
```

Human confirmation remains mandatory.

---

## 36. AI Confidence Routing

```text
HIGH CONFIDENCE
 ↓
Show recommendation
 ↓
Human confirmation
```

```text
MEDIUM CONFIDENCE
 ↓
Secondary review / additional checks
 ↓
Human review
```

```text
LOW CONFIDENCE
 ↓
UNDETERMINED
 ↓
Manual inspection
```

Never force uncertain AI into PASS or FAIL.

---

## 37. Future SteriCord Vision Engine

Do not train the custom proprietary model during the initial MVP.

Instead collect labelled data from the start:

```text
original image
indicator manufacturer
indicator model
indicator type
AI prediction
AI confidence
human-confirmed result
capture metadata
```

Future model targets:

```text
Bowie-Dick classification
Type 4 chemical indicator
Type 5 chemical indicator
BI vial classification
BI tray recognition
Washer test classification
```

---

## 38. AI Safety

AI must not:

```text
autonomously release packs
autonomously declare a patient-safe result
autonomously unlock equipment
autonomously remove quarantine
```

AI may:

```text
assist
extract
classify
recommend
highlight
flag
score confidence
```

---

## 39. Equipment Lockout

Do not allow AI alone to lock equipment.

Workflow:

```text
Test Failure
 ↓
Authorized Human Verification
 ↓
Lockout Initiated
 ↓
Equipment = LOCKED_OUT
 ↓
Audit Event
```

Unlock requires:

```text
Passed Retest
+
Authorized Supervisor
+
Reason
+
Timestamp
+
Audit Record
```

---

## 40. Phase 7 — Compliance & Reporting

Build:

```text
Audit trail views
Evidence hashing
Compliance reports
Retention rules
Exports
Incident reports
Equipment reports
Cycle reports
Evidence sheets
```

---

## 41. Phase 8 — Offline, Security & Pilot Hardening

Before hospital pilot:

```text
Offline capture
Encrypted local queue
Retry synchronization
Conflict handling
Monitoring
Backups
MFA
Security testing
Device testing
Performance testing
AI validation
Pilot deployment configuration
```

---

## 42. Offline Architecture

```text
Capture
 ↓
Encrypted Local Storage
 ↓
Local Operation ID
 ↓
Sync Queue
 ↓
Internet Restored
 ↓
Server Synchronization
 ↓
Server Acknowledgement
 ↓
Local State Reconciled
```

Synchronization states:

```text
LOCAL_ONLY
SYNC_PENDING
SYNCING
SYNCED
SYNC_FAILED
CONFLICT
```

Never silently discard failed uploads.

---

## 43. Security

Implement:

```text
Supabase Auth
RLS
Tenant isolation
Role-based authorization
Private evidence buckets
Signed URLs
HTTPS
Secure environment variables
Audit logging
Secure sessions
Rate limiting where appropriate
```

Prepare for:

```text
MFA
SSO
Microsoft Entra ID
Hospital Active Directory
Device authorization
IP restrictions
```

---

## 44. Storage Security

Evidence storage must support:

```text
private buckets
signed URLs
cryptographic hashes
server-authorized access
retention policies
```

Production providers should eventually support:

```text
Object Lock
WORM
Lifecycle archiving
7-year retention
```

---

## 45. UI Design

Visual direction:

```text
Deep Navy
White
Light Blue
Teal
Green = PASS
Amber = Warning
Red = FAIL / Critical
```

Design principles:

```text
clean
medical
professional
modern
high-trust
clear
accessible
not flashy
```

---

## 46. Dashboard

Initial dashboard:

```text
Today's Tests
Cycles Completed
Packs Released
OT Verifications
Open Alerts
Equipment Status
Recent Activity
```

---

## 47. QR System

Each instrument pack receives a unique QR.

QR resolves to SteriCord data such as:

```text
pack identity
instrument set
sterilization cycle
equipment
sterilized date
expiry date
verification status
current lifecycle state
```

Do not encode sensitive data directly.

---

## 48. Error Handling

Every network/API operation must handle:

```text
loading
success
validation error
authentication error
authorization error
network error
server error
retry
```

---

## 49. Validation

Validate on:

```text
frontend
+
backend
+
database
```

Validate:

```text
required fields
timestamps
equipment state
cycle state
pack state
role permissions
verification sequence
retention rules
```

---

## 50. Testing

Create progressively:

```text
unit tests
database tests
RLS tests
authorization tests
workflow tests
API tests
component tests
integration tests
```

Critical tests:

```text
Hospital A cannot access Hospital B

Released pack cannot come from a failed cycle

Quarantined pack cannot be used

Failed OT verification creates an incident

Unauthorized user cannot unlock equipment

Critical audit events cannot be modified through normal application access
```

---

## 51. Git Workflow

Use:

```text
main
develop
feature/*
fix/*
```

Examples:

```text
feature/authentication
feature/equipment
feature/sterilization-cycles
feature/instrument-packs
feature/ot-verification
feature/incidents
feature/evidence-storage
feature/image-quality
feature/ocr
feature/ai-analysis
feature/reporting
```

Commit examples:

```text
feat: add equipment registry
feat: implement sterilization cycle creation
feat: add OT failure incident workflow
feat: integrate evidence image quality checks
feat: integrate document OCR
feat: add multimodal AI analysis
fix: prevent quarantined pack verification
refactor: extract storage provider abstraction
```

---

## 52. Development Rules

1. Do not generate the entire application in one uncontrolled step.
2. Inspect the repository before making changes.
3. Preserve working code.
4. Use reusable components.
5. Use strict TypeScript.
6. Avoid `any`.
7. Keep business logic outside UI components.
8. Use abstractions where they provide real value.
9. Use database migrations for schema changes.
10. Never hard-code secrets.
11. Document important architectural decisions.
12. Do not introduce unnecessary microservices during MVP development.

---

## 53. Milestone 1 — Digital Traceability Walking Skeleton

Complete when:

```text
Login
 ↓
Create Equipment
 ↓
Create Sterilization Cycle
 ↓
Create Pack
 ↓
Generate QR
 ↓
Capture Evidence
 ↓
Manual PASS
 ↓
Scan QR
 ↓
View Full Pack History
```

AI is not required for this milestone.

---

## 54. Milestone 2 — Point-of-Use Safety

Complete when:

```text
OT Nurse Login
 ↓
Scan Pack
 ↓
Check Pack
 ↓
Capture Indicator
 ↓
PASS / FAIL
```

FAIL must:

```text
Create Incident
Alert CSSD
Quarantine Pack
Create Audit Event
```

---

## 55. Milestone 3 — AI-Assisted Capture

Complete when the workflow contains:

```text
OpenCV
+
Document AI
+
Gemini
+
Confidence Engine
+
Human Verification
```

---

## 56. Milestone 4 — Compliance

Complete when:

```text
Audit Trail
Evidence Hashing
Reports
Retention Logic
Role Review
Security Review
```

are functional.

---

## 57. Milestone 5 — Hospital Pilot

Complete when:

```text
Offline Capability
Reliable Sync
Monitoring
Backups
Performance Testing
MFA
Security Testing
Device Testing
AI Validation
Pilot Deployment
```

are complete.

---

## 58. Future Enterprise Features

Do not prioritize until pilot readiness:

```text
HL7 / FHIR
Mirth Connect
Hospital HIS integration
Enterprise SSO
Custom SteriCord Vision Engine
Complex billing
Advanced analytics
Multi-region deployment
Additional storage providers
Advanced compliance integrations
```

Design so they can be added later without a total rewrite.

---

## 59. Before Writing Code

Before major changes:

1. Inspect the current repository.
2. Explain briefly what exists.
3. State which files will be created.
4. State which files will be modified.
5. Identify dependencies.
6. Check for architectural conflicts.
7. Then implement.

Do not repeatedly ask for confirmation for routine decisions.

Ask only when:

```text
a requirement is genuinely ambiguous
a destructive migration is required
credentials are required
an external account must be configured
a major architectural decision cannot be inferred
```

---

## 60. After Each Feature

Provide:

```text
WHAT WAS BUILT

FILES CREATED

FILES MODIFIED

DATABASE CHANGES

HOW TO RUN

HOW TO TEST

EXPECTED RESULT

KNOWN LIMITATIONS

NEXT RECOMMENDED TASK
```

Provide exact terminal commands where needed.

---

## 61. First Development Sequence

Start with:

```text
STEP 1
Inspect repository.

STEP 2
Initialize monorepo if required.

STEP 3
Initialize Flutter application.

STEP 4
Initialize React + TypeScript web application.

STEP 5
Initialize Supabase local/project structure.

STEP 6
Create environment templates.

STEP 7
Create organizations.

STEP 8
Create departments.

STEP 9
Create profiles and roles.

STEP 10
Implement Row-Level Security.

STEP 11
Implement authentication.

STEP 12
Implement role-aware routing.

STEP 13
Create dashboard shells.

STEP 14
Implement Equipment CRUD.

STEP 15
Test tenant isolation and permissions.
```

Do not proceed to sterilization-cycle development until the foundation is stable.

---

## 62. Continue Through the Roadmap

After Phase 1 is stable:

```text
Phase 2 — CSSD Core
Phase 3 — OT Point-of-Use
```

Then begin mandatory AI stages:

```text
Phase 4 — OpenCV / Image Quality
Phase 5 — OCR / Document AI
Phase 6 — Gemini / Multimodal AI
```

Then:

```text
Phase 7 — Compliance & Reporting
Phase 8 — Offline / Security / Pilot Hardening
```

Do not interpret the instruction to delay AI as an instruction to remove AI.

AI is part of the required final system.

---

## 63. Final Quality Standard

Generated code should be:

```text
clean
modular
typed
maintainable
secure by default
testable
production-oriented
well-documented where necessary
```

Avoid unnecessary complexity, but also avoid shortcuts that clearly require a total redesign later.

---

## 64. Final Start Instruction

Inspect the repository now.

Begin with **Phase 1 — Foundation**.

Do not skip ahead.

Once Phases 1–3 are functional, continue through OpenCV, OCR, and multimodal AI as mandatory phases.

The target is a complete **SteriCord pilot-ready system**, not merely a UI prototype.
