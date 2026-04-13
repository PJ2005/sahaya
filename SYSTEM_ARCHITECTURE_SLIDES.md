# Sahaya Architecture Slide Pack

This version is optimized for presentations: concise narrative, high-signal diagrams, and cloud-platform-agnostic language.

## Slide 1: System Vision
Sahaya is an AI-assisted NGO operations platform that converts fragmented field inputs into prioritized action, volunteer dispatch, and verified completion outcomes.

```mermaid
flowchart LR
    subgraph Clients
      NGO[NGO App]
      VOL[Volunteer App]
      TG[Telegram Intake]
    end

    subgraph Core Platform
      AUTH[Firebase Auth]
      FS[(Firestore)]
      FCM[Cloud Messaging]
      API[Flask Backend]
    end

    subgraph External Services
      GEM[Gemini]
      CLD[Cloudinary]
      CPN[Cloud Platform Webhook]
    end

    NGO <--> FS
    VOL <--> FS
    NGO <--> AUTH
    VOL <--> AUTH
    NGO <--> FCM
    VOL <--> FCM

    TG --> API
    API <--> FS
    API <--> GEM
    API <--> CLD
    API <--> FCM
    API -.optional.-> CPN
```

## Slide 2: End-to-End Architecture (Detailed)

```mermaid
flowchart TD
    A[Ingest reports/media] --> B[(raw_uploads)]
    B --> C[Extraction + normalization]
    C --> D[Gemini extraction]
    D --> E[(problem_cards)]
    E --> F[NGO review/approve]
    F --> G[Task generation]
    G --> H[(tasks)]
    H --> I[Matching engine]
    I --> J[(match_records)]
    J --> K[Volunteer execution + proof]
    K --> L[Auto/manual proof verification]
    L --> M[Approve or reject]
    M --> N[Completion cascade + impact]
    M --> O[Rejection alert + resubmission loop]
```

## Slide 3: Component Diagram

```mermaid
flowchart LR
    subgraph Flutter NGO
      N1[ngo_dashboard]
      N2[ngo_home]
      N3[review/proof screens]
      N4[chat + notifications]
      N5[impact + heatmap]
    end

    subgraph Flutter Volunteer
      V1[gateway/auth/onboarding]
      V2[volunteer_home]
      V3[active_task]
      V4[task_chat + chat_hub]
      V5[volunteer_notifications]
    end

    subgraph Shared
      S1[models]
      S2[services]
      S3[components]
      S4[theme + l10n]
    end

    subgraph Backend
      B1[Webhook ingest]
      B2[AI extract/edit]
      B3[Task generation]
      B4[Matching + redispatch]
      B5[Proof verify]
      B6[Offline sync resolver]
      B7[Simulation + reminders]
    end

    N1 --> S1
    N2 --> S2
    N3 --> S3
    V2 --> S1
    V3 --> S2
    V5 --> S3
    S2 --> Backend
```

## Slide 4: Module/Package Structure

```mermaid
flowchart TD
    ROOT[sahaya]
    ROOT --> LIB[lib]
    ROOT --> BACK[services/telegram-webhook]
    ROOT --> RULES[firestore.rules]

    LIB --> ENTRY[main/app/flavors]
    LIB --> PAGES[pages/*]
    LIB --> MODELS[models/*]
    LIB --> SERVICES[services/*]
    LIB --> COMPONENTS[components/*]
    LIB --> UX[theme + l10n]

    BACK --> API[app.py]
    BACK --> DEPLOY[Dockerfile + cloudbuild]
```

## Slide 5: Class Diagram (Core Domain)

```mermaid
classDiagram
    class ProblemCard {
      id
      ngoId
      issueType
      severityLevel
      status
      priorityScore
      createdAt
    }
    class TaskModel {
      id
      problemCardId
      taskType
      status
      estimatedVolunteers
      isProofSubmitted
    }
    class MatchRecord {
      id
      taskId
      volunteerId
      status
      matchScore
      adminReviewNote
      proof
    }
    class ProofObject {
      photoUrls
      note
      submittedAt
    }
    class VolunteerProfile {
      uid
      skillTags
      radiusKm
      languagePref
      availabilityWindowActive
      trustScore
      tasksCompleted
    }

    ProblemCard "1" --> "many" TaskModel
    TaskModel "1" --> "many" MatchRecord
    MatchRecord "0..1" --> "1" ProofObject
    VolunteerProfile "1" --> "many" MatchRecord
```

## Slide 6: Sequence - Intake to Match

```mermaid
sequenceDiagram
    participant NGO as NGO/Telegram
    participant API as Flask API
    participant GEM as Gemini
    participant FS as Firestore

    NGO->>API: Upload report/media
    API->>FS: raw_uploads (pending)
    API->>GEM: Extract problems
    GEM-->>API: Structured JSON
    API->>FS: problem_cards (pending_review)
    NGO->>FS: Approve problem card
    NGO->>API: /generate-tasks
    API->>GEM: Decompose tasks
    API->>FS: tasks (open)
    API->>FS: match_records (open)
```

## Slide 7: Sequence - Proof Approval/Rejection Loop

```mermaid
sequenceDiagram
    participant VOL as Volunteer
    participant APP as Volunteer App
    participant API as Flask API
    participant NGO as NGO Admin
    participant FS as Firestore

    VOL->>APP: Submit proof
    APP->>FS: match_records.status=proof_submitted
    APP->>API: /notify-proof-submitted
    API->>FS: AI rubric + confidence writeback

    alt auto-approve
      API->>FS: status=proof_approved
      APP->>API: /complete-task
      API->>FS: completion cascade
    else manual review
      API->>FS: ngo_notifications create
      NGO->>FS: reject + adminReviewNote
      NGO->>API: /notify-proof-rejected
      API->>FS: volunteer_notifications create
      VOL->>APP: open resubmission alert
      VOL->>APP: resubmit proof
    end
```

## Slide 8: DFD Level 0

```mermaid
flowchart LR
    NGO[NGO] --> SYS[Sahaya System]
    VOL[Volunteer] --> SYS
    TG[Telegram] --> SYS
    SYS --> NGO
    SYS --> VOL
    SYS <--> GEM[Gemini]
    SYS <--> CLD[Cloudinary]
    SYS <--> FCM[Cloud Messaging]
```

## Slide 9: DFD Level 1 and 2

```mermaid
flowchart TD
    P1[Intake] --> D1[(raw_uploads)]
    P2[AI extraction] --> D2[(problem_cards)]
    P3[Task generation] --> D3[(tasks)]
    P4[Matching] --> D4[(match_records)]
    P5[Proof verification] --> D4
    P6[Notifications] --> D5[(ngo/volunteer_notifications)]

    D1 --> P2 --> D2 --> P3 --> D3 --> P4 --> D4 --> P5 --> P6
```

```mermaid
flowchart LR
    A[proof_submitted] --> B{Auto threshold pass?}
    B -->|yes| C[proof_approved]
    B -->|no| D[manual NGO review]
    D -->|approve| C
    D -->|reject| E[proof_rejected + note]
    E --> F[volunteer alert]
    F --> G[resubmission]
    G --> A
```

## Slide 10: ERD + Schema View

```mermaid
erDiagram
    NGO_PROFILES ||--o{ PROBLEM_CARDS : owns
    PROBLEM_CARDS ||--o{ TASKS : has
    TASKS ||--o{ MATCH_RECORDS : has
    VOLUNTEER_PROFILES ||--o{ MATCH_RECORDS : receives
    TASKS ||--o{ TASK_CHAT_MESSAGES : contains
    NGO_PROFILES ||--o{ NGO_NOTIFICATIONS : receives
    VOLUNTEER_PROFILES ||--o{ VOLUNTEER_NOTIFICATIONS : receives
    RAW_UPLOADS ||--o{ PROBLEM_CARDS : source
```

```mermaid
flowchart LR
    subgraph Firestore
      A[(users)]
      B[(ngo_profiles)]
      C[(volunteer_profiles)]
      D[(raw_uploads)]
      E[(problem_cards)]
      F[(tasks)]
      G[(match_records)]
      H[(task_chats/messages)]
      I[(ngo_notifications)]
      J[(volunteer_notifications)]
      K[(quality_events)]
      L[(sync_conflicts)]
      M[(scenario_runs)]
    end

    B --> E --> F --> G
    C --> G
    F --> H
    B --> I
    C --> J
    D --> E
```

## Slide 11: API Interaction + Use Cases + User Flows

### API Interaction

```mermaid
flowchart LR
    APPS[Flutter Apps] --> API[Flask API]
    API --> FS[(Firestore)]
    API --> GEM[Gemini]
    API --> CLD[Cloudinary]
    API --> TG[Telegram API]
    API --> FCM[Cloud Messaging]
```

### Use Cases

```mermaid
flowchart TB
    NGO[NGO Admin] --> U1[Ingest and review reports]
    NGO --> U2[Generate tasks and supervise matching]
    NGO --> U3[Review proofs, approve/reject]
    VOL[Volunteer] --> U4[Accept mission]
    VOL --> U5[Submit and resubmit proof]
    SYS[System] --> U6[Auto-match and auto-verify]
    SYS --> U7[Notify stakeholders]
```

### User Flows

```mermaid
flowchart LR
    NGO_Login --> NGO_Upload --> NGO_Review --> NGO_Generate --> NGO_ProofReview --> NGO_Decide
    VOL_Login --> VOL_Availability --> VOL_Mission --> VOL_Proof --> VOL_Result
    NGO_Decide -->|reject| VOL_Result
    VOL_Result -->|resubmit| VOL_Proof
```

## Slide 12: State Machines

```mermaid
stateDiagram-v2
    [*] --> open
    open --> accepted
    accepted --> proof_submitted
    accepted --> expired
    proof_submitted --> proof_approved
    proof_submitted --> proof_rejected
    proof_rejected --> proof_submitted
    proof_approved --> completed
    completed --> [*]
```

```mermaid
stateDiagram-v2
    [*] --> unread
    unread --> read
    read --> [*]
```

## Slide 13: Deployment Diagram (Cloud Platform Agnostic)

```mermaid
flowchart TB
    subgraph Local
      D1[Flutter flavors]
      D2[Flask service]
      D3[Optional Firebase emulators]
    end

    subgraph Build
      B1[Container image build]
    end

    subgraph Cloud
      C1[Managed Cloud Platform A\ncontainer runtime]
      C2[Managed Cloud Platform B\ncontainer runtime]
    end

    subgraph Runtime Dependencies
      R1[(Firestore)]
      R2[Cloud Messaging]
      R3[Gemini]
      R4[Cloudinary]
      R5[Telegram API]
      R6[Cloud platform webhook optional]
    end

    D2 --> B1
    B1 --> C1
    B1 --> C2

    C1 --> R1
    C1 --> R2
    C1 --> R3
    C1 --> R4
    C1 --> R5
    C1 -.-> R6

    C2 --> R1
    C2 --> R2
    C2 --> R3
    C2 --> R4
    C2 --> R5
    C2 -.-> R6
```

## Presenter Notes (Optional)
- Keep the narrative loop simple: intake -> intelligence -> dispatch -> verification -> measurable impact.
- Highlight deterministic safeguards around AI outputs (schema sanitization, constrained taxonomies, bounded scoring).
- Emphasize the rejection-resubmission loop and offline sync conflict policy as real-world reliability features.
