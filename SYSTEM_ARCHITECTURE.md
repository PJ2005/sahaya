# Sahaya System Architecture Deep Dive

This document is a code-driven architecture analysis of Sahaya, based on the current implementation in:
- [lib](lib)
- [services/telegram-webhook](services/telegram-webhook)
- [firestore.rules](firestore.rules)
- [firebase.json](firebase.json)
- [pubspec.yaml](pubspec.yaml)

## 1. System Architecture Diagram (High-Level)

What this shows:
- Two role-based Flutter clients
- A Python Flask backend for orchestration and AI flows
- Firestore/Auth/FCM as core platform services
- External integrations (Gemini, Telegram, Cloudinary, optional cloud-platform webhook)

```mermaid
flowchart LR
    subgraph Clients
      NGO[NGO App\nFlutter flavor: ngo]
      VOL[Volunteer App\nFlutter flavor: volunteer]
      TG[Telegram User/Bot]
    end

    subgraph Firebase
      AUTH[Firebase Auth]
      FS[(Cloud Firestore)]
      FCM[Firebase Cloud Messaging]
    end

    subgraph Backend
      API[Flask API\nservices/telegram-webhook/app.py]
    end

    subgraph External
      GEM[Google Gemini]
      CLD[Cloudinary]
      CPN[Cloud Platform Notification Webhook]
    end

    NGO --> AUTH
    VOL --> AUTH
    NGO <--> FS
    VOL <--> FS
    NGO <--> FCM
    VOL <--> FCM

    TG --> API
    API <--> FS
    API <--> FCM
    API <--> GEM
    API <--> CLD
    API -.optional.-> CPN
```

## 2. System Architecture Diagram (Detailed)

What this shows:
- End-to-end operational loop from intake to completion
- Where AI, deterministic scoring, and notifications are applied

```mermaid
flowchart TD
    A[Multi-channel Intake\nTelegram/App text/image/audio/doc] --> B[raw_uploads]
    B --> C[Extraction Service\nOCR/PDF/CSV/Text/Audio path]
    C --> D[Gemini extract-problems API]
    D --> E[problem_cards\nstatus: pending_review]

    E --> F[NGO Review + AI edit]
    F --> G[problem_cards approved]
    G --> H[generate-tasks endpoint]
    H --> I[tasks\nstatus: open]

    I --> J[run-matching endpoint]
    J --> K[match_records\nstatus: open]
    K --> L[Volunteer accepts\nstatus: accepted]
    L --> M[Volunteer proof submit\nstatus: proof_submitted]

    M --> N[notify-proof-submitted endpoint]
    N --> O{Auto-approve?\nconfidence>=85 and tamper<=35}
    O -->|yes| P[status: proof_approved\ntrust/tasksCompleted update]
    O -->|no| Q[ngo_notifications\nmanual review required]
    Q --> R[NGO decision]
    R -->|approve| P
    R -->|reject| S[status: proof_rejected\nadminReviewNote]
    S --> T[notify-proof-rejected\nvolunteer_notifications]
    T --> U[Volunteer resubmits proof]
    U --> M

    P --> V[complete-task endpoint]
    V --> W[tasks completionCount/status done]
    W --> X[problem_cards resolved when sibling tasks done]

    I --> Y[redispatch-cycle/redispatch-task\nexpire stale accepted -> rematch]
```

Example:
- Proof rejection now loops the volunteer back with admin note and explicit resubmission notification, rather than silently resetting progress.

## 3. Component Diagram

```mermaid
flowchart LR
    subgraph Flutter NGO
      NGO_D[ngo_dashboard]
      NGO_H[ngo_home_screen]
      NGO_R[review_queue/proof screens]
      NGO_C[ngo_chat_hub + notifications]
      NGO_I[impact + heatmap + monitor]
    end

    subgraph Flutter Volunteer
      VOL_G[volunteer_gateway/auth/onboarding]
      VOL_H[volunteer_home_screen]
      VOL_A[active_task_screen]
      VOL_C[task_chat + chat_hub]
      VOL_N[volunteer_notifications]
    end

    subgraph Shared UI/Logic
      COMP[components/*]
      SVC[services/*]
      MOD[models/*]
      THM[theme/* + l10n]
    end

    subgraph Backend Components
      ING[Webhook ingestion]
      EX[Extraction + normalization]
      GEN[Task generation]
      MAT[Matching engine]
      PRF[Proof verification]
      SYNC[Offline sync resolver]
      RED[Redispatch scheduler logic]
      SIM[Scenario simulation]
    end

    NGO_D --> COMP
    NGO_H --> SVC
    NGO_R --> MOD
    NGO_C --> MOD
    NGO_I --> MOD

    VOL_G --> COMP
    VOL_H --> SVC
    VOL_A --> SVC
    VOL_C --> MOD
    VOL_N --> MOD

    SVC --> Backend Components
    Backend Components --> MOD
    THM --> NGO_D
    THM --> VOL_H
```

## 4. Module/Package Structure Diagram

```mermaid
flowchart TD
    ROOT[sahaya]
    ROOT --> LIB[lib]
    ROOT --> BACK[services/telegram-webhook]
    ROOT --> FIRE[firestore.rules]
    ROOT --> CFG[firebase.json]

    LIB --> ENTRY[main.dart + main_ngo.dart + main_volunteer.dart + app.dart]
    LIB --> PAGES[pages]
    LIB --> MODELS[models]
    LIB --> SERVICES[services]
    LIB --> COMPONENTS[components]
    LIB --> THEME[theme]
    LIB --> L10N[l10n]

    PAGES --> NGO_P[ngo_* screens]
    PAGES --> VOL_P[volunteer/* screens]

    BACK --> APPPY[app.py]
    BACK --> REQS[requirements.txt]
    BACK --> DOCKER[Dockerfile]
    BACK --> CBUILD[cloudbuild.yaml]
    BACK --> CCFG[provider-specific deployment config]
```

## 5. Class Diagram (Core Domain Models)

Based on concrete model definitions in:
- [lib/models/problem_card.dart](lib/models/problem_card.dart)
- [lib/models/task_model.dart](lib/models/task_model.dart)
- [lib/models/match_record.dart](lib/models/match_record.dart)
- [lib/models/volunteer_profile.dart](lib/models/volunteer_profile.dart)
- [lib/models/raw_upload.dart](lib/models/raw_upload.dart)
- [lib/models/chat_message.dart](lib/models/chat_message.dart)

```mermaid
classDiagram
    class ProblemCard {
      +String id
      +String ngoId
      +IssueType issueType
      +String locationWard
      +String locationCity
      +GeoPoint locationGeoPoint
      +SeverityLevel severityLevel
      +int affectedCount
      +String description
      +double confidenceScore
      +ProblemStatus status
      +double priorityScore
      +DateTime createdAt
    }

    class TaskModel {
      +String id
      +String problemCardId
      +TaskType taskType
      +String description
      +List skillTags
      +int estimatedVolunteers
      +double estimatedDurationHours
      +TaskStatus status
      +List assignedVolunteerIds
      +bool isProofSubmitted
      +String locationWard
      +GeoPoint locationGeoPoint
    }

    class MatchRecord {
      +String id
      +String taskId
      +String volunteerId
      +double matchScore
      +MatchStatus status
      +String missionBriefing
      +String whatToBring
      +ProofObject proof
      +String adminReviewNote
      +DateTime completedAt
    }

    class ProofObject {
      +List photoUrls
      +String note
      +DateTime submittedAt
    }

    class VolunteerProfile {
      +String id
      +String uid
      +String username
      +GeoPoint locationGeoPoint
      +double radiusKm
      +List skillTags
      +String languagePref
      +bool availabilityWindowActive
      +bool isPartialAvailability
      +DateTime availabilityUpdatedAt
      +String fcmToken
      +int tasksCompleted
      +int trustScore
    }

    class RawUpload {
      +String id
      +String ngoId
      +String cloudinaryUrl
      +String cloudinaryPublicId
      +String fileType
      +DateTime uploadedAt
      +UploadStatus status
    }

    class ChatMessage {
      +String id
      +String senderId
      +String senderName
      +String text
      +DateTime timestamp
    }

    ProblemCard "1" --> "many" TaskModel : decomposes into
    TaskModel "1" --> "many" MatchRecord : generates
    MatchRecord "0..1" --> "1" ProofObject : contains
    VolunteerProfile "1" --> "many" MatchRecord : assigned through
    TaskModel "1" --> "many" ChatMessage : task chat thread
```

## 6. Sequence Diagrams (Key Workflows)

### 6.1 Intake -> Extraction -> Task Generation

```mermaid
sequenceDiagram
    participant NGO as NGO/Telegram User
    participant APP as NGO App or Telegram
    participant API as Flask Backend
    participant CLD as Cloudinary
    participant GEM as Gemini
    participant FS as Firestore

    NGO->>APP: Submit text/image/audio/document
    APP->>API: webhook or extraction request
    API->>CLD: Upload media (if file)
    API->>FS: Create raw_uploads (pending)
    API->>GEM: Extract structured problems
    GEM-->>API: JSON problem candidates
    API->>FS: Create problem_cards (pending_review)
    NGO->>APP: Review and approve card
    APP->>API: POST /generate-tasks
    API->>GEM: Decompose task list
    API->>FS: Create tasks
    API->>API: Run matching per task
    API->>FS: Create match_records (open)
```

### 6.2 Proof Submit -> Auto/Manual Review -> Completion

```mermaid
sequenceDiagram
    participant V as Volunteer
    participant APP as Volunteer App
    participant FS as Firestore
    participant API as Flask Backend
    participant NGO as NGO Admin

    V->>APP: Submit proof photos + note
    APP->>FS: match_records.status=proof_submitted, proof object
    APP->>API: POST /notify-proof-submitted
    API->>FS: Load match/task/problem context
    API->>API: AI rubric + confidence check

    alt auto-approved
      API->>FS: status=proof_approved, trust/tasksCompleted update
      APP->>API: POST /complete-task
      API->>FS: task completion cascade
    else manual review
      API->>FS: Create ngo_notifications (proof_submitted)
      NGO->>FS: Reject with adminReviewNote
      NGO->>API: POST /notify-proof-rejected
      API->>FS: Create volunteer_notifications (proof_rejected)
      V->>APP: Opens resubmission required alert
      V->>APP: Resubmits proof
    end
```

### 6.3 Offline Sync Conflict Path

```mermaid
sequenceDiagram
    participant V as Volunteer App
    participant LQ as Local Queue (SharedPreferences)
    participant API as Flask /sync-task-update
    participant FS as Firestore

    V->>LQ: queue proof_submit/task_update action
    V->>V: connectivity restored
    V->>API: replay queued action(s)
    API->>FS: compare clientUpdatedAt vs server updatedAt

    alt conflict
      API->>FS: log sync_conflicts + quality_events
      API-->>V: policy=server_wins
    else no conflict
      API->>FS: apply updates
      API-->>V: status=applied
    end

    V->>LQ: clear/apportion queue
```

## 7. Data Flow Diagrams

### 7.1 DFD Level 0 (Context)

```mermaid
flowchart LR
    NGO[NGO User] --> SYS[Sahaya Platform]
    VOL[Volunteer User] --> SYS
    TG[Telegram] --> SYS
    SYS --> NGO
    SYS --> VOL

    SYS <--> GEM[Gemini]
    SYS <--> CLD[Cloudinary]
    SYS <--> FCM[Firebase Cloud Messaging]
```

### 7.2 DFD Level 1 (Major Processes)

```mermaid
flowchart TD
    P1[1. Intake and Upload] --> D1[(raw_uploads)]
    P2[2. AI Extraction + Normalize] --> D2[(problem_cards)]
    P3[3. NGO Review + Task Generation] --> D3[(tasks)]
    P4[4. Volunteer Matching] --> D4[(match_records)]
    P5[5. Proof Submission + Verification] --> D4
    P6[6. Notifications] --> D5[(ngo_notifications, volunteer_notifications)]
    P7[7. Completion + Impact] --> D2

    D1 --> P2
    D2 --> P3
    D3 --> P4
    D4 --> P5
    P5 --> P6
    P5 --> P7
```

### 7.3 DFD Level 2 (Proof Verification Subsystem)

```mermaid
flowchart TD
    A[Proof uploaded from app] --> B[(match_records.proof)]
    B --> C[notify-proof-submitted]
    C --> D[AI rubric evaluation]
    D --> E{Auto-approve thresholds met?}
    E -->|yes| F[Update status proof_approved]
    E -->|no| G[Create ngo_notifications proof_submitted]
    G --> H[NGO manual decision]
    H -->|approve| F
    H -->|reject| I[status proof_rejected + adminReviewNote]
    I --> J[notify-proof-rejected]
    J --> K[(volunteer_notifications)]
    K --> L[Volunteer resubmission]
    L --> A
```

## 8. ERD for Data Models

```mermaid
erDiagram
    NGO_PROFILES ||--o{ PROBLEM_CARDS : owns
    PROBLEM_CARDS ||--o{ TASKS : has
    TASKS ||--o{ MATCH_RECORDS : has
    VOLUNTEER_PROFILES ||--o{ MATCH_RECORDS : receives
    TASKS ||--o{ TASK_CHAT_MESSAGES : contains
    NGO_PROFILES ||--o{ NGO_NOTIFICATIONS : receives
    VOLUNTEER_PROFILES ||--o{ VOLUNTEER_NOTIFICATIONS : receives
    RAW_UPLOADS ||--o{ PROBLEM_CARDS : source_for

    PROBLEM_CARDS {
      string id PK
      string ngoId FK
      string issueType
      string severityLevel
      string status
      string locationWard
      string locationCity
      double priorityScore
      datetime createdAt
    }
    TASKS {
      string id PK
      string problemCardId FK
      string taskType
      string status
      int estimatedVolunteers
      bool isProofSubmitted
    }
    MATCH_RECORDS {
      string id PK
      string taskId FK
      string volunteerId FK
      string status
      double matchScore
      string adminReviewNote
      object proof
      datetime createdAt
    }
```

## 9. Database Schema Diagram (Firestore Collections)

```mermaid
flowchart LR
    subgraph Firestore
      U[(users)]
      NP[(ngo_profiles)]
      VP[(volunteer_profiles)]
      RU[(raw_uploads)]
      PC[(problem_cards)]
      T[(tasks)]
      MR[(match_records)]
      TN[(task_chats/{taskId}/messages)]
      NN[(ngo_notifications)]
      VN[(volunteer_notifications)]
      QE[(quality_events)]
      SC[(sync_conflicts)]
      TL[(telegram_links)]
      SR[(scenario_runs)]
    end

    NP --> PC
    PC --> T
    T --> MR
    VP --> MR
    T --> TN
    NP --> NN
    VP --> VN
    RU --> PC
    MR --> SC
    RU --> QE
```

Schema notes:
- Canonical state-bearing collections: tasks, match_records, problem_cards
- Event/audit collections: quality_events, sync_conflicts, scenario_runs
- Notification collections are role-separated for tighter read rules

## 10. API Interaction/Integration Diagram

### 10.1 Endpoint Surface (from [services/telegram-webhook/app.py](services/telegram-webhook/app.py))

| Method | Route |
|---|---|
| GET | / |
| GET | /health |
| POST | /webhook |
| POST | /generate-tasks |
| POST | /run-matching |
| POST | /redispatch-task |
| POST | /redispatch-cycle |
| POST | /sync-task-update |
| POST | /simulate-scenario |
| POST | /send-availability-reminders |
| POST | /notify-proof-submitted |
| POST | /complete-task |
| POST | /notify-proof-rejected |
| POST | /api/gemini/extract-problems |
| POST | /api/gemini/extract-problems-audio |
| POST | /api/gemini/ai-edit |
| POST | /api/gemini/ai-edit-list |

### 10.2 Integration Diagram

```mermaid
flowchart LR
    APPS[Flutter Apps] --> API[Flask API]
    API --> FS[(Firestore)]
    API --> GEM[Gemini API]
    API --> CLD[Cloudinary]
    API --> TGA[Telegram API]
    API --> FCM[Firebase Messaging]
  API -.optional.-> CPN[Cloud platform notification webhook]

    APPS --> FS
    APPS --> FCM
```

## 11. Use Case Diagram

```mermaid
flowchart TB
    NGO[Actor: NGO Admin]
    VOL[Actor: Volunteer]
    SYS[Actor: System Automation]

    UC1[Upload/ingest report]
    UC2[Review extracted problem]
    UC3[Generate tasks]
    UC4[Run matching]
    UC5[Accept mission]
    UC6[Submit proof]
    UC7[Auto verify proof]
    UC8[Manual approve/reject]
    UC9[Resubmit rejected proof]
    UC10[Close task + impact update]

    NGO --> UC1
    NGO --> UC2
    NGO --> UC3
    NGO --> UC8
    NGO --> UC10

    VOL --> UC5
    VOL --> UC6
    VOL --> UC9

    SYS --> UC4
    SYS --> UC7

    UC1 --> UC2 --> UC3 --> UC4 --> UC5 --> UC6 --> UC7
    UC7 --> UC10
    UC7 --> UC8
    UC8 --> UC10
    UC8 --> UC9 --> UC6
```

## 12. User Journey / User Flow Diagrams

### 12.1 NGO Journey

```mermaid
flowchart TD
    A[Login NGO app] --> B[Upload report or ingest Telegram item]
    B --> C[Review extracted problem card]
    C --> D[Approve + generate tasks]
    D --> E[Monitor matches and chat]
    E --> F[Review submitted proof]
    F --> G{Approve or Reject}
    G -->|Approve| H[Completion cascade + impact]
    G -->|Reject| I[Provide admin note]
    I --> J[Volunteer resubmits]
    J --> F
```

### 12.2 Volunteer Journey

```mermaid
flowchart TD
    A[Login/onboard volunteer] --> B[Set availability + profile]
    B --> C[Receive/open matched mission]
    C --> D[Coordinate in task chat]
    D --> E[Do task + submit proof]
    E --> F{Review result}
    F -->|Approved| G[Mission completed]
    F -->|Rejected| H[See rejection alert + admin comment]
    H --> I[Resubmit proof]
    I --> E
```

Example:
- Rejection branch now explicitly notifies volunteer and opens active mission with admin review note for guided resubmission.

## 13. State Machine / State Transition Diagrams

### 13.1 Match Record State Machine

```mermaid
stateDiagram-v2
    [*] --> open
    open --> accepted: volunteer accepts
    accepted --> proof_submitted: volunteer uploads proof
    accepted --> expired: stale acceptance redispatch
    proof_submitted --> proof_approved: auto/manual approve
    proof_submitted --> proof_rejected: NGO rejects with note
    proof_rejected --> proof_submitted: volunteer resubmits
    proof_approved --> completed: completion cascade marker
    completed --> [*]
    expired --> [*]
```

### 13.2 Task State Machine

```mermaid
stateDiagram-v2
    [*] --> open
    open --> filled: volunteers assigned/accepted
    filled --> done: completionCount reaches estimate
    open --> done: edge case direct close
    done --> [*]
```

### 13.3 Notification State Machine

```mermaid
stateDiagram-v2
    [*] --> unread
    unread --> read: user opens/handles
    read --> [*]
```

## 14. Deployment Diagram (Infrastructure and Environments)

Observed deployment artifacts:
- Containerized backend via [services/telegram-webhook/Dockerfile](services/telegram-webhook/Dockerfile)
- GCP Cloud Run pipeline via [services/telegram-webhook/cloudbuild.yaml](services/telegram-webhook/cloudbuild.yaml)
- Provider-specific cloud deployment defaults via project deployment config

```mermaid
flowchart TB
    subgraph Local
      DEV1[Flutter dev run\nngo/volunteer flavors]
      DEV2[Flask app.py]
      EMU[Optional Firebase emulators]
      DEV1 --> DEV2
      DEV1 --> EMU
      DEV2 --> EMU
    end

    subgraph ContainerBuild
      IMG[Docker image: sahaya-backend]
    end

    subgraph CloudTargets
      CRUN[Cloud target path A\ncloudbuild.yaml]
      CAPP[Cloud target path B\ncontainerized app service]
    end

    subgraph RuntimeDeps
      FS[(Firestore)]
      FCM[Firebase Messaging]
      GEM[Gemini]
      CLD[Cloudinary]
      TG[Telegram API]
      CPN[Cloud platform webhook optional]
    end

    DEV2 --> IMG
    IMG --> CRUN
    IMG --> CAPP

    CRUN --> FS
    CRUN --> FCM
    CRUN --> GEM
    CRUN --> CLD
    CRUN --> TG
    CRUN -.-> CPN

    CAPP --> FS
    CAPP --> FCM
    CAPP --> GEM
    CAPP --> CLD
    CAPP --> TG
    CAPP -.-> CPN
```

Environment notes:
- Runtime uses env vars for credentials and service endpoints in [services/telegram-webhook/app.py](services/telegram-webhook/app.py)
- Flutter apps are flavor-separated via [lib/flavors.dart](lib/flavors.dart) and entrypoints [lib/main_ngo.dart](lib/main_ngo.dart), [lib/main_volunteer.dart](lib/main_volunteer.dart)

## 15. Accuracy Notes and Boundaries

- Diagrams reflect implemented code paths and current schema usage observed in the repo.
- Firestore is schemaless; schema diagrams represent effective application-level contracts, not strict database-enforced schemas.
- Some operational policies (for example, exact production target used at this moment) can support multiple cloud deployment paths.

