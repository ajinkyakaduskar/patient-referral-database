# The Patient Referral System — Design Walkthrough

The two problems this project addresses, why the schema is built the way it is, and how each
of the nine queries would function in practice.

**A note on the data.** The examples below use the actual rows in `patient_referral_database.sql`
— patient `PT04` (Sara Lance), referral `R007`, physician `PH01` (Marc Spector, Cardiology). The
dataset is a 6-patient demonstration set written to exercise the schema, not a population sample.
Every name is fictional.

---

## The two problems

A referral is when a primary-care doctor sends a patient to a specialist. In the US this handoff
breaks in two distinct ways.

**Problem A — the referral gets lost.** The referral goes out and nobody watches what happens to
it. Did it reach the specialist? Was the patient scheduled? Did the visit happen? A 2018 study of
103,737 appointment scheduling attempts across 24 primary-care sites found that only **34.8%**
resulted in a documented completed appointment. Not because anyone is careless — because no single
system tracks the referral end to end. It falls into the gap between two organizations that don't
talk, and is often discovered only when the patient turns up sicker in an ER.

**Problem B — the referral arrives empty.** Even when it reaches the specialist, it often arrives
as a name and a one-line reason. Medication history, past diagnoses, family and social history,
recent vitals — all left behind in the sending clinic's system. A 2011 national survey of 4,720
physicians found a 34-point perception gap: **69% of primary-care physicians said they always or
mostly sent patient history with a referral, while fewer than 35% of specialists said they always
or mostly received it.** A more recent 2022 survey found 78% of PCPs reporting they send clinical
information at referral, so the picture has improved — but the gap between sent and received is
the durable finding.

> Layman: Problem A is "the referral got lost in the mail." Problem B is "the referral arrived,
> but the envelope was empty."
>
> Clinical: Problem A is loop-closure failure; Problem B is missing clinical context at the point
> of specialty care.
>
> Engineer: Problem A is the absence of a shared, stateful record tracking referral lifecycle
> across organizations; Problem B is data fragmentation — the records exist but aren't linked or
> transmitted with the referral.

This project addresses both through two different parts of the design. **Status tracking** on the
`visit` table addresses Problem A. **The schema** — how the tables link — addresses Problem B.

---

## The plumbing underneath: HL7, interface engines, and the HIE

Before the queries, the layer beneath the database: how data physically moves between two
organizations.

The core problem is that hospitals speak different languages. Each runs its own EHR, each storing
data its own way. Everything below exists to fix that.

**HL7 — the shared language.** HL7 (Health Level Seven) is the messaging standard hospitals use to
exchange clinical information. When an event happens — a patient is admitted, a result comes back,
a referral is placed — the system generates a message describing it. Messages come in types, one
per event: ADT (admit/discharge/transfer), ORM (an order), ORU (a result), SIU (scheduling), and
REF (a referral — the one this project uses). Two generations exist: HL7 v2, the older pipe-
delimited text format that still carries most real-time traffic, and FHIR, the modern web-API
version organizing data into resources (`Patient`, `Observation`, and `ServiceRequest` for
referrals).

**Inbound vs outbound is just direction.** Outbound is a message leaving a system; inbound is that
same message arriving at another. Same letter, different end of the delivery.

**The interface engine.** Even with a shared standard, systems have formatting quirks, and one
hospital may run dozens of systems that need to talk. Wiring each directly to every other is
unmanageable. So hospitals use an interface engine — Rhapsody is a leading one (others: Cloverleaf,
Mirth Connect, Epic Bridges). It sits in the middle and does four things: receives messages,
translates them to fix formatting differences, routes them to the right destination, and sends them
out. Each system connects once to the engine instead of to every other system — hub and spoke.

> Engineer: a message broker doing protocol translation, data transformation, and content-based
> routing across inbound and outbound interfaces, decoupling source from destination.

**The HIE — the shared network between organizations.** Interface engines move data within or out
of one organization. A referral crosses between two. That's what a Health Information Exchange is
for: a shared network multiple organizations connect to. In Massachusetts, Mass HIway (the
state-designated HIE) and NEHEN. Neither hospital owns it — which is exactly why the tracking
record should live there: one source of truth both sides feed and read.

**The full path:** sending EHR → (outbound HL7 REF) → sending interface engine → HIE → receiving
interface engine → (inbound) → receiving EHR. Every arrow is a message; every hop through an
organization passes through an engine; the HIE is the shared middle; and the tracking record rides
on that shared middle, holding status as the referral passes through.

**The honest gap that makes this worth building.** These same hospitals already run mature HL7
interfaces for labs and radiology — that plumbing is near-universal. It just isn't reliably applied
to referrals. So this isn't a "build the pipes" problem. The pipes exist. It's a workflow-and-
tracking gap layered on top of pipes that are already there.

**The interview one-liner:** *"The transport is HL7 — a REF message — moving through interface
engines like Rhapsody that translate and route between systems. Between two separate organizations
that exchange happens across a health information exchange like Mass HIway or NEHEN. My database
isn't the transport; it's the tracking layer on the shared exchange, fed by those interfaces,
holding the referral's status across both organizations."*

---

## Why the schema is the heart of the project

Thirteen tables, and the design principle is that **the patient visit is the central hub**.
Everything connects through the visit — demographics, medication history, social and family
history, diagnosis, vitals, orders, billing, and the communication trail.

Because everything links back to the visit, the referral doesn't travel alone. The full clinical
picture can be assembled and sent with it — that's the fix for the empty-envelope problem. And
because the tables are properly related, you can ask questions across the whole picture in a single
query, which is what makes the tracking and analytics possible at all.

> Layman: a well-organized filing cabinet where every document about a patient is cross-referenced,
> so pulling one file brings the related ones with it.
>
> Clinical: the encounter is where data is generated, so anchoring on it keeps the clinical story
> intact through the handoff.
>
> Engineer: a normalized schema with the encounter as hub, child tables referencing it, and
> patient/physician as dimensions — supporting both transactional lookups and analytical queries
> without duplication.

**The honest maturity point.** Auditing my own first build, I found foreign keys wired in the wrong
direction, a table with no primary key, and blood pressure stored as text. The queries still ran —
joins match on values, not constraints — but the integrity was broken underneath. Catching that is
the difference between something that works and something that's correct. The rebuild fixed the
relationships and made the referral its own status-tracked entity.

---

## Who owns this, and where the tables actually live

Three layers, three owners:

- **The sending clinic** owns its own EHR. Demographics, history, the visit, the vitals all live
  there, created by staff during ordinary care. Most of this schema describes what a sending
  clinic's system must hold — which a real EHR already does.
- **The receiving hospital** owns its own EHR, with its own tables.
- **The shared tracking layer on the HIE** — the genuinely new piece this design proposes: one
  record of every referral and its status, owned by neither organization and read by both.

So the schema is a blueprint for two things at once: what a clinic's system must capture, and what
the shared tracking layer must carry. It isn't something a hospital installs instead of Epic; it's
the design for what sits on top.

**Where the tables physically live — the point worth being precise about.** The tables do not move
to the HIE. They stay in the sending clinic's database. What travels is a *message assembled from
them* — a snapshot, not the tables.

The analogy: the tables are filing cabinets in the clinic. When a referral goes out, nobody ships
the cabinets. Someone opens the relevant drawers, copies the pages that matter, staples them into a
packet, and sends that. The packet is the HL7 message. The cabinets never leave.

For any table the sequence is: *created here → stays here → read at referral time to fill part of
the outgoing message.* A table never "lands in the HIE"; its contents ride along inside a message.

**Who does what:** the physician triggers the referral by placing the order. The EHR assembles the
message by reading across these tables. The interface engine translates and routes it. The HIE
carries it and holds the shared status record. A coordinator watches that record and chases what
stalls.

---

## The 13 tables

Read each as four things: what it stores, who creates the row and when, where it lives, and what
part of the referral message it feeds.

### Group 1 — People and reference lists

**`patient_demographics`** — `patient_id` (PK), name, gender, DOB, phone, address.
*Created by* registration staff, once, the first time the patient registers — long before any
referral exists. *Lives in* the clinic's EHR permanently; in a real system `patient_id` is the MRN.
*Feeds* the patient identification segment. This is the one part of the message that never gets
left out, even in a fax workflow. It's also how the receiving side and the HIE match the patient to
records they already hold — get it wrong and the referral attaches to the wrong person.

**`physician_main`** — `physician_id` (PK), name, NPI, specialization, hospital.
*Created by* credentialing when a clinician joins; maintained as a directory, not per-referral.
*Lives in* each organization's system and increasingly in shared provider directories on the HIE —
which is how a referring doctor can find a specialist at another organization at all. *Feeds* the
message twice: the referring provider, and the intended recipient specialty. NPI is the National
Provider Identifier, the unique 10-digit number every US clinician carries; it's what makes a
provider identifiable *across* organizations, which is why it travels rather than a local ID. You
don't refer "to a doctor," you refer "to cardiology" — specialization is what routes the referral.

**`laboratory_tests`** — `test_id` (PK), department, investigation.
*Created by* the lab as a catalogue — the fixed menu of tests offered, set up once and rarely
changed. *Feeds* indirectly: it turns an order's ID into readable text ("Electrocardiogram,
Cardiology") inside the orders portion of the message. Classic lookup table — the name is written
once, and every order points at the ID instead of repeating the words.

### Group 2 — The hub

**`visit`** — `visit_id` (PK), `patient_id` and `physician_id` (FKs), `referral_id` (UNIQUE),
`referral_status`, `visit_datetime`, `hospital`.

*Created by* the EHR the moment the encounter opens. *Lives in* the clinic's EHR and — uniquely
among these tables — its referral columns are mirrored onto the shared HIE record. This is the one
table whose data doesn't just get copied and sent: `referral_id` and `referral_status` *become* the
shared tracking record both organizations read and update. *Feeds* the message as its spine: the
referral identifier, status, encounter date, facility, and the links to patient and provider.

**Why it's the hub:** everything clinical happens during a visit — vitals at a visit, diagnosis at
a visit, orders at a visit, billing for a visit. It's the one event every fact attaches to, and
what ties a fact to a moment in time. In Epic terms it maps to the encounter/CSN.

**It plays two roles at once:** a child of `patient` and `physician` (a visit belongs to them, so
it holds their IDs), and a parent to `vital_signs`, `disease`, `orders`, `billing` (those belong to
a visit, so they hold its ID).

**The two columns the project exists for:** `referral_id` is the tracking number; `referral_status`
is the state — `initiated` → `scheduled` → `completed`. `referral_id` is `UNIQUE` for a technical
reason: `communication_table` points at it with a foreign key, and a foreign key can only reference
a guaranteed-unique column.

### Group 3 — The clinical record of a visit

**`vital_signs`** — `visit_id` as both PK and FK (one visit, one set), plus height, weight,
systolic, diastolic, temperature, pulse, respiratory rate.
*Created by* the nurse in the first five minutes of the appointment. *Feeds* the clinical bundle as
observations (FHIR `Observation` resources, or OBX segments), so the specialist can see "BP was
145/100 at the referring visit" before the patient arrives. **The fix baked in:** the original
stored BP as the text `'145/100'`, which can't be compared numerically. Splitting into two integers
is what makes Q2's risk query possible at all.

**`disease`** — `serial_number` (surrogate PK), `icd`, `patient_id`, `specialization`,
`final_diagnosis`, `test_id`, `visit_id`.
*Created by* the physician on reaching a working diagnosis. *Feeds* the reason for referral — the
most important clinical field after patient identity. The ICD code (`I25.1` = coronary artery
disease) makes the diagnosis machine-readable, countable, comparable across hospitals and billable,
which is why codes travel rather than free text. `specialization` here is literally what determines
where the referral goes, and what lets Q6 find patients seen under two specialties.

**`orders`** — `order_id` (PK), `visit_id`, `test_id`, `order_date`.
*Created by* the physician during the visit. One visit can generate several — which is exactly why
this is its own table rather than columns on the visit. *Feeds* the tests already ordered or
pending, so the specialist doesn't needlessly repeat them. **The fix baked in:** the original
`orders` table had no primary key at all, so duplicate rows were possible and no single order could
be reliably referenced.

**`billing`** — `billing_id` (PK), `visit_id`, insurance company, coverage.
*Created by* the billing system after the encounter. *Feeds* partly: coverage often travels with a
referral, because authorization and network status determine whether the specialist can see the
patient at all. Out-of-network status and missing prior authorization are among the most common
reasons a referral stalls, so coverage is a genuine referral-risk field, not just accounting.

### Group 4 — The patient's background

**`medical_history`** (conditions, allergies), **`social_history`** (smoking, alcohol, duration),
**`family_history`** (relatives' conditions), **`medication_history`** (drugs, doses, start dates).

*Created by* clinicians and intake staff over time, across many visits — accumulated background,
not a snapshot. *Feed* the clinical summary that travels with the referral (in reality a C-CDA
document, or FHIR `Condition`, `MedicationStatement`, `AllergyIntolerance` resources).

**This is the heart of Problem B.** In today's broken workflow, this is precisely the material left
behind — the referral arrives with a name and a one-line reason while the medication list,
allergies and family history stay in the sending system. The information isn't missing from the
world; it's stuck in one clinic. Because these tables link to the patient, and the patient links to
the visit and its referral, the whole picture can be assembled and sent in one go. That single
difference is the fix.

**Why four tables instead of one:** each repeats. A patient has many medications, many past
conditions, many family conditions. Anything that happens many times for one person needs its own
table with one row per occurrence. **The fix baked in:** the original used `patient_id` as both
primary and foreign key here, limiting each patient to exactly one history row.

### Group 5 — The referral trail

**`communication_table`** — `communication_id` (PK), `referral_id` (FK), date, sent to, method
(Email, Phone, Voicemail, Fax), notes.
*Created by* the system automatically when a message goes out electronically, and manually by a
coordinator when contact happens outside the system. *Lives* ideally on the shared HIE layer beside
the referral status, so both organizations see the chase history. *Feeds* nothing outbound — it
records the messages sent *about* the referral. One referral → many communications, so the
communication row holds the referral's key. **The fix baked in:** in the original build this
relationship was wired backwards.

**Why `method` matters and isn't trivia:** how a referral is chased is a risk signal. Electronic
channels populate this field automatically; phone and fax must be logged by hand, and every manual
step is a place data goes missing. Naming that limitation is stronger than pretending capture is
complete.

### What feeds what

| Part of the outgoing referral | Comes from |
|---|---|
| Who the patient is | `patient_demographics` |
| Who is referring, and to which specialty | `physician_main` + `disease.specialization` |
| Referral ID, status, encounter date, facility | `visit` |
| Reason for referral (ICD-coded) | `disease` |
| Recent vitals | `vital_signs` |
| Tests already ordered | `orders` + `laboratory_tests` |
| Insurance / coverage | `billing` |
| Meds, allergies, family & social history | the four history tables — *the part usually left behind* |
| The chase log | `communication_table` (records, doesn't feed) |

**One line:** the tables stay in the clinic's system; at referral time the EHR reads across them to
assemble one message; the interface engine routes it onto the HIE; and only the visit's referral ID
and status live on the shared layer as the tracking record both sides read and update.

---

## Following one referral through the tables

**Step 0 — the reference data already exists.** Before Sara Lance (`PT04`) walks in, her
demographics row exists from her first registration. `physician_main` already holds the provider
directory. `laboratory_tests` already lists the menu. And `medical_history`, `medication_history`
and `family_history` already hold her background — coronary artery disease, a citrus allergy,
atorvastatin and aspirin since June 2023, a father with cardiac history.

Note what is *not* there: `PT04` has **no `social_history` row at all**. Only two of six patients
do. That absence isn't a gap in the story — it's the story. It's why Chart 6 puts social history at
33%, and it's exactly the kind of context that quietly fails to travel with a referral.

**Step 1 — the visit row is born.** Sara sees Dr. Spector with chest discomfort. The moment the
encounter opens:

```
V007 | PT04 | PH01 | R007 | initiated | 2024-03-19 14:00 | Mass General Brigham Hospital
```

Read that row: `V007` identifies the encounter; `PT04` says it's Sara; `PH01` says Spector saw her;
the timestamp fixes it in time; and `R007` / `initiated` are the referral's tracking number and
state. Before this row a referral is an intention in a doctor's head. After it, it's a record with
an ID and a state.

The child tables fill in as care happens:

- Vitals → `V007 | 160 | 58.0 | 145 | 100 | 37.5 | 88 | 18`. Keyed on `visit_id` — one visit, one
  set. And 145/100 is high. Because systolic and diastolic are separate integers rather than text,
  the system can compare them, which is what makes the next step possible.
- Diagnosis → `I25.1 | PT04 | Cardiology | Coronary artery disease | LT04 | V007`.
- Orders → `O006` (ECG) and `O007` (lipid panel), both on `V007`. Two orders from one visit — which
  is why `orders` is its own table.
- Billing → `B004 | V007 | Cigna | Full`.

At the end of Step 1 everything about Sara is reachable from one place. From `V007` you can walk to
her identity, her physician, her vitals, her diagnosis, her orders, her bill — and through her
`patient_id`, to her medications, allergies and family history. That is what "the visit is the hub"
means in practice.

**Step 2 — leaving the sending organization.** The EHR generates an outbound HL7 REF message and
hands it to the interface engine, which translates and routes it onto the HIE. The message is a
snapshot assembled from the tables: the referral identifier and status, the patient, the referring
physician and target specialty, the encounter details, the clinical picture — and critically, the
background from the four history tables.

Contrast with today, where the same referral leaves as a fax carrying a name and a one-line reason.
That difference — the bundle travelling versus not travelling — is Problem B, solved purely because
the schema links everything to the patient and the visit.

The first communication row is written: `C007 | R007 | 2024-03-20 09:00 | Dr. Spector | Email |
Urgent referral`.

**Step 3 — arriving at the receiving organization.** Their interface engine picks the message up
from the HIE — inbound from their point of view, the same message that was outbound from the
sender. It lands as a structured referral with the clinical bundle attached, not a fax in a tray.

Two mechanisms are worth distinguishing:

- **Push** (what just happened): the referral was sent with everything attached. Event-driven.
- **Query/pull:** if the specialist wants more — records from a third hospital two years ago — they
  query the HIE for that patient. In the real world this is Care Everywhere or a Carequality query.

The receiving organization never reaches into the sender's database. Those are separate
organizations with separate systems and real privacy walls. They either receive what was pushed, or
query the shared exchange. The HIE is always the intermediary. That's the honest architecture, and
it's the thing people usually get wrong when they imagine one hospital looking into another's
system.

When the referral is scheduled, the shared record moves `initiated` → `scheduled`, and both sides
see it. If nobody acts, it stays at `initiated` — visibly stalled rather than silently lost.

**Step 4 — the rescue.** Suppose nothing happens and the referral sits at `initiated`. A
coordinator runs a query each morning: *which referrals are still open past N days, high-risk
first?* `visit` supplies the referral, status and date; `patient_demographics` says who they are;
`vital_signs` and `medical_history` supply the risk factors that push Sara to the top (systolic 145,
coronary artery disease — the Q2 logic); `communication_table` shows what chasing has been tried.

She surfaces on that list this week, while it still matters. The coordinator calls, gets her
scheduled, and logs it: `C013 | R007 | 2024-03-21 | Dr. Spector | Email | Reminder`.

Today none of this is possible — not through carelessness, but because no single place holds every
referral's status, so there is no list to look at.

**Step 5 — closing the loop, and where it actually breaks.** For the loop to close, the receiving
organization must actively send status and results back through the same path, moving the record to
`completed` with the specialist's report attached. Then the referring doctor finally learns what the
specialist found.

The forward direction is the easy half. The return half depends on the receiving organization
sending status back, their system being configured for it, and both organizations having agreed the
connection. That return-status gap is precisely why closed-loop rates sit around a third. **A
database can hold a closed loop; it cannot force both ends to report into it.** Saying that plainly
is stronger than pretending the design solves it.

---

## What this schema doesn't model yet

Worth naming, because a reviewer will spot it. The `visit` table carries **one** `hospital` column.
A genuine cross-organization tracking record needs two — a referring organization and a receiving
organization — plus timestamps for each status transition, so "days open" can be computed rather
than inferred. As built, the schema tracks *that* a referral has a status; it doesn't yet model the
handoff between two named parties or when each transition happened. That's the first thing I'd add
in a v2, alongside the `VARCHAR` change already made.

---

## The nine queries

The full annotated SQL is in `patient_referral_database.sql`, Section 3. The snippets discussed in
interviews are simplified versions of those — the file is authoritative.

| Query | What it asks | The technique worth explaining |
|---|---|---|
| Q1 | Patient summary with visit count | `LEFT JOIN` keeps patients with no history or no visits; `GROUP BY` collapses the row multiplication the second join creates. `GROUP BY` makes the buckets, `COUNT` tallies them. |
| Q2 | High-risk patients | Vitals belong to a *visit*, so the path is patient → visit → vitals — different join keys at each hop. `OR` widens the net; `AND` would return almost nobody. |
| Q3 | Physicians below average load | `LEFT JOIN` is essential — zero-visit physicians are the answer, and `INNER JOIN` would delete them. `HAVING` not `WHERE`, because the count doesn't exist until after grouping. Nested subquery, read inside-out, resolves to a single threshold (1.5 here). |
| Q4 | Age band + most recent order | `CASE` is if/then/else for a column and stops at the first true branch, so branch order matters. Age is calculated with `AGE()`/`EXTRACT`, not stored. |
| Q5 | Repeat lab orders in 2024 | The question hides two filters in two places: "during 2024" filters raw rows (`WHERE`); "more than once" filters the count (`HAVING`). Hearing which is which is the skill. |
| Q6 | Patients in both Cardiology and Pulmonary | You cannot write `specialization = 'Cardiology' AND specialization = 'Pulmonary'` — `WHERE` tests one row, and one row holds one value. The patient is in both as two separate rows, so it needs a subquery with `IN`. Set intersection. |
| Q7 | Most-used communication method | The top-N recipe: `GROUP BY` + `COUNT` + `ORDER BY DESC`. Note `IS NOT NULL`, never `= NULL`. |
| Q8 | Share of referrals per hospital | Scalar subquery supplies the denominator. Postgres does integer division (3/6 = 0), so the numerator is cast `::numeric` — MySQL does this automatically, a real dialect difference. `COUNT(DISTINCT …)` so a repeat visitor isn't double-counted. |
| Q9 | Patients with no allergy recorded | `LEFT JOIN` keeps patients with no history row at all — the most incomplete records, which `INNER JOIN` would hide. Catches both `NULL` and `''`. |

**The through-line.** Q1, Q6 and Q9 are about completeness (Problem B). Q2, Q5, Q7 and Q8 are about
tracking and risk (Problem A). Q3 and Q4 are capacity and population views.

**The recurring lessons, said once:** `LEFT JOIN` keeps the rows you'd otherwise lose. `GROUP BY`
collapses multiplied rows into one bucket per group so an aggregate can measure each. `WHERE` filters
raw rows before grouping; `HAVING` filters aggregates after. `CASE` turns a value into a category,
stopping at the first true branch. A subquery supplies a value the outer query needs first — an
average, a total, or a list to match against.

---

## Summary

The US referral process breaks two ways: referrals get lost, and referrals arrive empty. A
relational schema built around the patient visit links all of a patient's clinical data, so the full
picture can travel with the referral. A shared tracking layer — living on an exchange both
organizations connect to via HL7/FHIR interfaces — gives every referral a status from `initiated` to
`completed`, so stalled referrals become visible and can be rescued before harm. Nine SQL queries
turn that into an operational toolkit: flagging high-risk patients, surfacing repeat referrals,
measuring where referrals concentrate, and checking data completeness.

The honest boundaries: the return trip is the hardest part and depends on both sides reporting in;
out-of-band communication still requires manual logging; and the schema as built models one hospital
per visit rather than a referring/receiving pair.

---

## Sources

- Closing the Referral Loop: an Analysis of Primary Care Referrals to Specialists in a Large Health
  System. *Journal of General Internal Medicine*, 2018.
  https://link.springer.com/article/10.1007/s11606-018-4392-z
- O'Malley AS, Reschovsky JD. Referral and Consultation Communication Between Primary Care and
  Specialist Physicians. *Archives of Internal Medicine*, 2011 (n = 4,720 physicians).
- Communication Gaps Persist Between Primary Care and Specialist Physicians. *Annals of Family
  Medicine*, 2022. https://www.annfammed.org/content/20/4/343
