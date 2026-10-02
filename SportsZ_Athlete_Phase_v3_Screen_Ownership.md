# SPORTSZ — ATHLETE PHASE v3.0
## FINAL SCREEN-WISE FULL-STACK OWNERSHIP (5 MEMBERS)

**Source of truth:** Athlete Phase v2.1 (screen IDs, APIs, collections, ADR-001, stub register S-01…S-14). Nothing was invented: no new screens, collections or features. Where the source has gaps they are listed in the "Open items" section at the end.
**Counted from the source:** 113 Athlete screens (O03, O04, G01–G04 removed; ST07 and X02 reserved for Coach Phase; PR04 does not exist in the source).
**Rule of this version:** one screen → one owner → that owner builds Flutter + state + API integration + FastAPI + MongoDB + validation + authorization + states + tests. Other members only *consume* the documented API.

---

# 1. FINAL ATHLETE SCREEN-WISE DISTRIBUTION

| Member | Module | Screens | Own endpoints (≈) | Own collections | Foundation held |
|---|---|---|---|---|---|
| **M1** | Identity, Profile & Account | **38** — A01–A08 · O01–O12 (no O03/O04) · P01–P07 · P15–P16 · I01–I04 · PR02/PR03/PR05 · E04 · ST02/ST03 · X01 | 24 | users, athlete_profiles, sports, sports_ids, organizations, organization_members | FastAPI skeleton, envelope/errors, Firebase auth dependency, Mongo connection/index runner, sports seed, Flutter router + shell + route guards |
| **M2** | Home, Dashboard, Notifications, Settings & Help | **16** — H01–H02 · D01 · N01–N02 · ST01/ST04/ST05/ST06 · HS01–HS07 | 16 | notifications, feedback_reports, jobs, audit_logs | Flutter architecture, API client, design system + shared components, `ConfigFormRenderer`, jobs/outbox, `AuditService`, `NotificationService.emit`, deep-link router, CI |
| **M3** | Explore, Opportunities, Applications, Events & Recognition | **26** — E01–E03 · E05–E07 · S01 · OP01–OP03 · AP01–AP05 · EV01–EV06 · P24–P28 | 32 | opportunities, applications, saved_items, events, event_registrations, leaderboard_snapshots, badges, athlete_badges, points_ledger | `SearchProjectionService`, `EligibilityService` |
| **M4** | Messaging, Connections, Coach Links & Privacy Access | **14** — M01–M05 · C01–C02 · L01–L02 · PR01/PR06/PR07/PR08/PR09 | 24 + authz core | connections, coach_athlete_links, access_grants, conversations, messages, platform_config | `viewer_context`, `authorize()`, `project()` + field registry, rate limiting, `AccessGrantService`, seed CLI + fixtures + Dev Counterpart Console |
| **M5** | Sports Record, Evidence & Verification | **19** — P08–P14 · P17–P23 · V01–V05 | 39 | performance_entries, metric_bests, achievements, media, documents, verification_requests | Docker (Mongo replica set, MinIO, ffmpeg, ClamAV), storage abstraction, signed URLs, file validation, `MetricValidator` |
| | **Total** | **113** | | **32 collections, each with one owner** | |

**Why this differs from your suggested grouping** (your grouping was validated against the real screen list):
- Your M5 (Sports Record + Evidence + Verification + Rankings/Badges/Points) would hold 24 screens *and* the heaviest backend (media pipeline, scanning, verification state machine, `metric_bests`). **Rankings, Badges, Points (P24–P28) move to M3**, together with Events, because event results feed records, rankings and badges. Still Phase 1.
- Your M3 (Explore/Search/Opportunities/Applications) gains Events and Recognition, and also owns `EligibilityService`, because opportunities *and* event registration both use it.
- Your M4 (Messages/Connections/Coach Links) is light on screens (9) but heavy on backend. It also gets the relationship-driven screens (Privacy center, Access grants, View-as, Blocked users) and the authorization core, because `authorize()` reads connections, links and grants.
- Your M2 (Home/Dashboard/Notifications/Settings) keeps those and adds Help & Support plus the shared Flutter foundation (design system, jobs, notifications service).
- Your M1 is unchanged in spirit, plus the screens whose APIs are already M1's: E04 (athlete viewer = same `GET /athletes/{id}`), ST02/ST03/X01 (account, security, logout).

**Relative load** (screens are not the measure): M1 = many simple forms, moderate backend · M2 = few screens, large shared foundation · M3 = largest endpoint and job count (search, jobs for rankings/badges, event capacity) · M4 = security-critical, on the critical path (authz core + messaging rules) · M5 = most complex pipelines (uploads, scanning, verification). M3 and M5 are the heaviest; agreed relief valve if either slips: P24–P28 and the badge/points job move from M3 to M2 (no API conflict, because they are self-contained).

**Mapping from v2.1 so nobody is confused:**

| v2.1 | Now |
|---|---|
| M1 Identity & Account | M1 (+E04, ST02, ST03, X01) |
| M2 Sports Record (+design system) | Sports record → **M5**; design system/Flutter architecture → **M2** |
| M3 Evidence & Trust | **M5** |
| M4 Discovery & Opportunities | Explore/Opportunities/Applications/Saved → **M3**; Connections/Coach links/Access grants/authz core → **M4** |
| M5 Experience & Management | Home/Dashboard/Notifications/Settings/Help/jobs → **M2**; Events/Rankings/Badges/Points → **M3**; Messaging/Privacy hub → **M4** |

**Split screens from v2.1 now fixed (UI owner ≠ API owner before):** E04 → M1 · PR01/PR06/PR07/PR08/PR09 → M4 · ST02/ST03/X01 → M1 · P24–P28 and EV01–EV06 → M3 (own both UI and backend) · M01–M05 → M4.

---

# 2. COMPLETE SCREEN OWNERSHIP MATRIX

**Reading rule:** for every row, **Flutter = API = Backend = DB owner = the Owner column** for the routes listed under *Builds*. *Uses* lists APIs or services owned by someone else, consumed only. A screen with "—" under Builds is Flutter-only (it consumes existing resource APIs and creates none).
**Auth:** every screen requires a signed-in Firebase user except A01–A07 (pre-auth) and the public ID page. **Authz codes:** OWN = owner only · PROJ = `authorize()`+`project()` (viewer sees only permitted fields) · PART = conversation/relationship participants only · REL = relationship/grant based · PUB = public whitelist · PRE = pre-auth.
**Tests:** the owner writes unit, API, integration, security and Flutter tests for every row.

### M1 — Identity, Profile & Account (38 screens)

| ID | Screen | Owner | Builds | Uses (owner) | DB | Authz |
|---|---|---|---|---|---|---|
| A01 | Splash | M1 | `POST /auth/session` (session restore) | Firebase | users | PRE |
| A02 | Welcome | M1 | — | — | — | PRE |
| A03 | Auth chooser | M1 | `POST /auth/session` | Firebase providers | users | PRE |
| A04 | Email form | M1 | `POST /auth/session` | Firebase email | users | PRE |
| A05 | Phone + OTP | M1 | `POST /auth/session` | Firebase phone | users | PRE |
| A06 | Recovery | M1 | — | Firebase reset | — | PRE |
| A07 | Session expired / error | M1 | `POST /auth/logout`, `POST /auth/session` | — | users | PRE/OWN |
| A08 | Link accounts | M1 | `GET /me` | Firebase link | users | OWN |
| O01 | Basic identity | M1 | `POST /me/roles/athlete`, `PATCH /me/profile/athlete` | M5 `POST /media/upload-url` (photo) | users, athlete_profiles | OWN |
| O02 | Date of birth | M1 | `PATCH /me/profile/athlete` | — | athlete_profiles | OWN |
| O05 | Sport selection | M1 | `GET /sports`, `PUT …/sports/{id}` | — | sports, athlete_profiles | OWN |
| O06 | Sport details | M1 | `GET /sports/{id}/config`, `PUT …/sports/{id}` | M2 `ConfigFormRenderer` | sports, athlete_profiles | OWN |
| O07 | About | M1 | `PATCH /me/profile/athlete` | — | athlete_profiles | OWN |
| O08 | Physical | M1 | `PATCH …/physical` | — | athlete_profiles | OWN |
| O09 | Privacy defaults | M1 | `PATCH …/privacy` | M4 `GET /me/privacy/schema` | athlete_profiles | OWN |
| O10 | Profile complete | M1 | `GET /me/profile/athlete` (completion) | — | athlete_profiles | OWN |
| O11 | SportsZ ID issued | M1 | `GET /me/sportsz-id` | — | sports_ids | OWN |
| O12 | Verify prompt | M1 | — (navigates to V03) | M5 V03 | — | OWN |
| P01 | My profile | M1 | `GET /me/profile/athlete` | M5 `/me/performance`, `/me/achievements`, `/me/media`; M3 `/me/badges` | athlete_profiles | OWN |
| P02 | Edit hub | M1 | — | P03–P07, P15 | — | OWN |
| P03 | Edit basics | M1 | `PATCH /me/profile/athlete` | M5 media upload (photo) | athlete_profiles | OWN |
| P04 | Edit about | M1 | `PATCH /me/profile/athlete` | — | athlete_profiles | OWN |
| P05 | Sports list | M1 | `POST …/sports/{id}/primary`, `DELETE …/sports/{id}` | — | athlete_profiles | OWN |
| P06 | Add / Edit sport | M1 | `PUT …/sports/{id}` | M2 renderer; `GET /sports/{id}/config` | athlete_profiles, sports | OWN |
| P07 | Physical | M1 | `PATCH …/physical` | — | athlete_profiles | OWN |
| P15 | Experience | M1 | `DELETE …/experience/{id}` | — | athlete_profiles | OWN |
| P16 | Add / Edit experience | M1 | `POST/PATCH …/experience` | `GET /organizations` (M1) | athlete_profiles, organizations | OWN |
| I01 | SportsZ ID | M1 | `GET /me/sportsz-id` | — | sports_ids | OWN |
| I02 | Share | M1 | — (client share sheet) | I01 data | — | OWN |
| I03 | QR | M1 | `POST /me/sportsz-id/rotate-qr` | — | sports_ids | OWN |
| I04 | ID page settings | M1 | `PATCH …/privacy`, `GET /id/{sportsz_id}` (public page) | — | athlete_profiles, sports_ids | OWN / PUB |
| PR02 | Discoverability | M1 | `PATCH …/privacy` | M4 `/me/privacy/schema`; enqueues M3 search rebuild | athlete_profiles | OWN |
| PR03 | Field visibility | M1 | `PATCH …/privacy` | M4 `/me/privacy/schema` | athlete_profiles | OWN |
| PR05 | Contact policy | M1 | `PATCH …/privacy` | M4 `/me/privacy/schema` | athlete_profiles | OWN |
| E04 | Athlete profile (viewer) | M1 | `GET /athletes/{sportsz_id}` | M5 `/athletes/{id}/performance|stats|achievements|media`; M3 `/athletes/{id}/badges`, `/saved`; M4 C01 connect, messaging entry | athlete_profiles | PROJ |
| ST02 | Account | M1 | `GET/PATCH /me` | Firebase re-auth | users | OWN |
| ST03 | Security | M1 | re-auth; sessions/devices revoke (see Open items) | Firebase | users | OWN |
| X01 | Logout dialog | M1 | `POST /auth/logout` | — | users | OWN |

### M2 — Home, Dashboard, Notifications, Settings & Help (16 screens)

| ID | Screen | Owner | Builds | Uses (owner) | DB | Authz |
|---|---|---|---|---|---|---|
| H01 | Home | M2 | `GET /me/home` (composed, stores nothing) | M1 profile, M5 performance, M3 events/opps, M4 links, notifications | — | OWN |
| H02 | Add sheet | M2 | — (shortcuts) | M5 P10/P14/P18 entry points | — | OWN |
| D01 | Dashboard | M2 | `GET /me/dashboard` (composed) | M5 verification, M3 applications/badges/points, M4 links/grants, M1 ID | — | OWN |
| N01 | Notifications | M2 | `GET /me/notifications`, `PATCH …/{id}/read`, `PATCH …/read-all` | deep-link router (M2) | notifications | OWN |
| N02 | Notification preferences | M2 | `GET/PUT /me/notification-prefs`, `POST/DELETE /me/devices` | — | notifications (prefs/devices as per Arch) | OWN |
| ST01 | Settings | M2 | — (hub) | ST02–ST06 | — | OWN |
| ST04 | Communication | M2 | `GET/PUT /me/notification-prefs` (assumed; confirm in UI spec) | M1 PR05 contact policy (link only) | notifications | OWN |
| ST05 | Data & account | M2 | `POST/GET /me/data-export` | — | jobs | OWN |
| ST06 | Delete account | M2 | `DELETE /me`, `POST /me/cancel-deletion` | M1 re-auth; every owner's purge handler | users (via M1 service), jobs | OWN |
| HS01–HS07 | Help & Support (7 screens) | M2 | `POST /reports`, `GET /me/reports` (FAQ static) | — | feedback_reports | OWN |

### M3 — Explore, Opportunities, Applications, Events & Recognition (26 screens)

| ID | Screen | Owner | Builds | Uses (owner) | DB | Authz |
|---|---|---|---|---|---|---|
| E01 | Explore hub | M3 | — (entry to search, directories, opportunities) | `GET /sports` (M1) | — | PROJ |
| E02 | Filter sheet | M3 | — (filter schema) | `GET /sports/{id}/config` (M1) | — | PROJ |
| E03 | Results | M3 | `POST /athletes/search` | M1 profile via projection | athlete_profiles.search.* (read; written only by M3's `SearchProjectionService`) | PROJ |
| E05 | Coach profile (viewer) | M3 | `GET /coaches`, `GET /coaches/{public_id}` | M4 C01 | coach directory (see Open items) | PROJ |
| E06 | Recruiter profile (viewer) | M3 | `GET /recruiters`, `GET /recruiters/{public_id}` | M4 C01 | recruiter directory (see Open items) | PROJ |
| E07 | Sport detail | M3 | — | `GET /sports/{id}/config` (M1) | — | OWN |
| S01 | Saved | M3 | `POST/DELETE /saved`, `GET /saved?type=` | M1 projection for athletes | saved_items | OWN |
| OP01 | Opportunities | M3 | `GET /opportunities` | — | opportunities | PROJ |
| OP02 | Opportunity detail | M3 | `GET /opportunities/{id}`; counterpart `POST/PATCH` (S-04) | — | opportunities | PROJ |
| OP03 | Eligibility sheet | M3 | `POST /opportunities/{id}/eligibility` | M1 profile facts, M5 `metric_bests` read service | — | OWN |
| AP01 | Applications | M3 | `GET /me/applications` | — | applications | OWN |
| AP02 | Application detail | M3 | `GET /applications/{id}`, `POST …/withdraw`; counterpart `PATCH …/status` (S-05) | M4 grants revoke on withdraw | applications | OWN |
| AP03 | Apply review | M3 | `POST /opportunities/{id}/applications` | M1/M5 summaries | applications | OWN |
| AP04 | Share scopes | M3 | — (scopes sent with AP03) | M4 `AccessGrantService` | — (grant stored by M4) | OWN |
| AP05 | Submitted | M3 | — | — | — | OWN |
| EV01 | Events | M3 | `GET /events` | — | events | PROJ |
| EV02 | Event detail | M3 | `GET /events/{id}`; counterpart `POST/PATCH /events` (S-02) | — | events | PROJ |
| EV03 | Register confirm | M3 | `POST /events/{id}/register` | `EligibilityService` (M3) | event_registrations | OWN |
| EV04 | Registration confirmation | M3 | — (result of EV03) | — | event_registrations | OWN |
| EV05 | My registrations | M3 | `GET /me/event-registrations`, `DELETE /events/{id}/register` | — | event_registrations | OWN |
| EV06 | Event results | M3 | `GET /events/{id}/results`; counterpart `POST …/results` (S-03) + results job | M5 `create_from_event` | events | PROJ |
| P24 | Badges | M3 | `GET /me/badges` | — | athlete_badges, badges | OWN |
| P25 | Badge detail | M3 | `GET /me/badges`, `GET /athletes/{id}/badges` | — | badges | OWN / PROJ |
| P26 | My rankings | M3 | `GET /leaderboards/own-rank` | M5 `metric_bests` read service | leaderboard_snapshots | OWN |
| P27 | Leaderboard | M3 | `GET /leaderboards` | M5 `metric_bests` read service | leaderboard_snapshots | PROJ |
| P28 | Points | M3 | `GET /me/points` | — | points_ledger | OWN |

### M4 — Messaging, Connections, Coach Links & Privacy Access (14 screens)

| ID | Screen | Owner | Builds | Uses (owner) | DB | Authz |
|---|---|---|---|---|---|---|
| M01 | Messages | M4 | `GET /conversations` | M2 notifications | conversations | PART |
| M02 | Search conversations | M4 | — (filters `GET /conversations`; no new route, see Open items) | — | conversations | PART |
| M03 | Conversation | M4 | `GET/POST /conversations/{id}/messages`, `POST …/read`; counterpart `/conversations*` (S-09) | M3 applications lookup (messaging rule), M2 emit | messages, conversations | PART |
| M04 | Conversation info | M4 | `PATCH …/mute`, `DELETE /conversations/{id}` | `POST /connections/{id}/block` (M4) | conversations | PART |
| M05 | New message | M4 | `POST /conversations` | M3 applications lookup | conversations | REL |
| C01 | Connect sheet | M4 | `POST /connections` | — | connections | REL |
| C02 | Connections | M4 | `GET /connections`, `POST …/respond`, `…/block`, `…/unblock` (S-08) | — | connections | OWN |
| L01 | My coaches | M4 | `GET /coach-links`, `POST /coach-links` (athlete-initiated), `POST …/end` | — | coach_athlete_links | OWN |
| L02 | Link request detail | M4 | `POST …/approve`, `…/decline`, `…/end` (S-06) | — | coach_athlete_links | PART |
| PR01 | Privacy center | M4 | — (hub) | `GET /me/privacy/schema` (M4), grants list | — | OWN |
| PR06 | Access grants | M4 | `GET /access-grants`, `POST /access-grants`, `…/revoke` | — | access_grants | OWN |
| PR07 | Grant request detail | M4 | `POST /access-grants/{id}/grant`, `…/revoke`; counterpart `POST …/requests` (S-10) | — | access_grants | OWN |
| PR08 | View as | M4 | `GET /me/profile/preview?as=` | `project()` (M4), M1 profile | — | OWN |
| PR09 | Blocked users | M4 | `GET /connections` (blocked), `POST …/unblock` | — | connections | OWN |

### M5 — Sports Record, Evidence & Verification (19 screens)

| ID | Screen | Owner | Builds | Uses (owner) | DB | Authz |
|---|---|---|---|---|---|---|
| P08 | Performance | M5 | `GET /me/performance` | M1 sport config | performance_entries, metric_bests | OWN |
| P09 | Performance detail | M5 | `GET/PATCH/DELETE /performance/{id}`; Coach Endorsed display/hide; counterpart endorse (S-07) | M2 `POST /reports`, M4 link status | performance_entries | OWN / PROJ |
| P10 | Add / Edit performance | M5 | `POST/PATCH /performance` | M2 renderer, `MetricValidator` (M5) | performance_entries | OWN |
| P11 | Metric history | M5 | `GET /me/performance?metric_key=`, `GET /athletes/{id}/stats` | — | performance_entries, metric_bests | OWN / PROJ |
| P12 | Achievements | M5 | `GET /me/achievements` | — | achievements | OWN |
| P13 | Achievement detail | M5 | `GET /achievements/{id}` | — | achievements | OWN / PROJ |
| P14 | Add / Edit achievement | M5 | `POST/PATCH/DELETE /achievements` | own media picker | achievements | OWN |
| P17 | Media gallery | M5 | `GET /me/media` | — | media | OWN |
| P18 | Upload media | M5 | `POST /media/upload-url`, `POST /media/{id}/confirm` | M5 pipeline | media | OWN |
| P19 | Media detail / player | M5 | `GET /media/{id}`, `GET …/playback-url` | — | media | OWN / PROJ |
| P20 | Edit media | M5 | `PATCH/DELETE /media/{id}` | — | media | OWN |
| P21 | Documents hub | M5 | `GET /me/documents` | — | documents | OWN |
| P22 | Upload document | M5 | `POST /documents/upload-url`, `…/confirm` | — | documents | OWN |
| P23 | Document detail | M5 | `GET /documents/{id}`, `GET …/url`, `PATCH/DELETE` | M4 grants (certificate scope) | documents | OWN / REL |
| V01 | Verification center | M5 | `GET /me/verification` | — | verification_requests | OWN |
| V02 | Domain list | M5 | `GET /me/verification` | — | verification_requests | OWN |
| V03 | Request verification | M5 | `POST /verification` | — | verification_requests | OWN |
| V04 | Request detail | M5 | `GET /me/verification/{id}` | — | verification_requests | OWN |
| V05 | Action required / resubmit | M5 | `POST /me/verification/{id}/resubmit`; counterpart decide (S-01) | — | verification_requests | OWN |

**Count check:** 38 + 16 + 26 + 14 + 19 = **113**. Every ID appears exactly once.

---

# 3. MEMBER 1 — COMPLETE MODULE

**Module name:** Identity, Profile & Account

**Screens (38):** A01–A08 · O01, O02, O05–O12 · P01–P07 · P15, P16 · I01–I04 · PR02, PR03, PR05 · E04 · ST02, ST03 · X01.

**Flutter:** `features/auth`, `onboarding` (draft + resume), `profile` (incl. `profile/viewer/` for E04), `sportsz_id`, `privacy_settings`, `account`; plus `lib/app/` router, shell, route guards. State: auth state, onboarding draft, forms, loading/empty/error.

**Backend:** Firebase token verification and user create/resolve; athlete profile service (validation against sport config, completion score); `ProfileCacheService` (only writer of verification-summary cache fields); SportsZ ID generation (non-sequential, check character, immutable); public ID page whitelist; viewer-side `GET /athletes/{id}` (calls M4 `authorize()`/`project()`); organizations read; sports config.

**API:** `POST /auth/session` · `POST /auth/logout` · `GET/PATCH /me` · `POST /me/roles/athlete` · `GET/PATCH /me/profile/athlete` · `PUT/DELETE /me/profile/athlete/sports/{id}` · `POST …/primary` · `PATCH …/physical` · `POST/PATCH/DELETE …/experience` · `PATCH …/privacy` · `GET /athletes/{sportsz_id}` · `GET /me/sportsz-id` · `POST …/rotate-qr` · `GET /id/{sportsz_id}` · `GET /sports`, `/sports/{id}/config` · `GET /organizations`, `/organizations/{public_id}`.

**Database:** users, athlete_profiles, sports, sports_ids, organizations, organization_members. (`athlete_profiles.search.*` is written only by M3's `SearchProjectionService`; the verification-summary fields only through M1's `ProfileCacheService`.)

**Testing:** sport-config validation, completion score, ID uniqueness/check character, DOB checks; every route 401/403/404/422 and `extra=forbid` on server-owned fields (`roles, status, user_id, verification_*, sportsz_id`); signup → onboarding → profile → ID against Firebase emulator + Mongo; athlete B reading/editing athlete A, public-ID whitelist snapshot, enumeration test, blocked user reading a profile; onboarding-resume Flutter tests. Extra: a 4th sport works by config only.

**Dependencies:** M4 `authorize()/project()` (S1–S2) · M2 design system + `ConfigFormRenderer` (S0–S1) · M5 media upload for profile photo (S1) · M4 `/me/privacy/schema` · M5/M3 verification apply handlers call M1's `ProfileCacheService` (S4).

**Can be consumed by:** every member (`/me`, `/athletes/{id}`, `/sports*`, auth dependency, envelope).

**Future Coach integration:** Coach/Recruiter/Admin read the *same* `athlete_profiles` through `GET /athletes/{id}`; the field registry (M4) already has role columns, so no new profile collection or API. Coach enrolment later adds a role to `users.roles`; nothing in Athlete changes.

**NOT responsible for:** performance, achievements, media, documents, verification workflow, search/explore, connections, coach links, opportunities, applications, events, messaging, notifications, rankings/badges/points, privacy hub/grants/view-as/blocked UI, account deletion/export (M2), design system, Coach/Recruiter enrolment, role switcher.

---

# 4. MEMBER 2 — COMPLETE MODULE

**Module name:** Home, Dashboard, Notifications, Settings & Help (+ shared Flutter foundation)

**Screens (16):** H01, H02 · D01 · N01, N02 · ST01, ST04, ST05, ST06 · HS01–HS07.

**Flutter:** `features/home`, `dashboard`, `notifications`, `settings`, `help`; plus `lib/core/` (Riverpod architecture, dio client with token/error interceptors, design tokens, theme, typography, shared components: buttons, inputs, chips, cards, 6-state verification badge, loading/empty/error widgets) and `ConfigFormRenderer`. Home is a structured sports-activity view, not a social feed.

**Backend:** home/dashboard composition (calls owners' APIs/services, stores nothing); notification service (emit, dispatch, push, preferences, devices, deep links); jobs worker + outbox; `AuditService` (append-only); reports handling; account deletion (soft delete 30 days) and data export, orchestrating each owner's purge handler; CI pipeline.

**API:** `GET /me/home`, `/me/dashboard` · `GET /me/notifications`, `PATCH …/{id}/read`, `PATCH …/read-all` · `GET/PUT /me/notification-prefs` · `POST/DELETE /me/devices` · `POST /reports`, `GET /me/reports`, `PATCH /admin/reports/{id}` (S-12) · `DELETE /me`, `POST /me/cancel-deletion`, `POST/GET /me/data-export` · `POST /dev/jobs/run-due` (S-14).

**Database:** notifications, feedback_reports, jobs, audit_logs (append-only; everyone writes through `AuditService.append`).

**Testing:** notification delivery/read/preference rules; deep-link routing; dashboard/home partial failure (one source down must not blank the screen); delete → purge across owners; export; report rate limit and reporter hidden from reported user; dev routes absent in production config; golden tests for shared components; widget docs for all members.

**Dependencies:** reads from every member's APIs (no copies); M1 re-auth for deletion; each owner's purge handler (S7).

**Can be consumed by:** all (design system, `NotificationService.emit`, `AuditService`, job runner, deep-link router).

**Future Coach integration:** notification types are a registry, so Coach adds types without editing Athlete code; the same components and jobs serve the Coach UI; `/me/home` and `/me/dashboard` stay athlete-scoped and Coach gets its own composed read models later.

**NOT responsible for:** profile data, performance, media/verification, search/opportunities/applications, events, messaging rules, rankings/badges/points, connections/links/grants, authorization core. Home/Dashboard must call owners' APIs, never read their collections.

---

# 5. MEMBER 3 — COMPLETE MODULE

**Module name:** Explore, Opportunities, Applications, Events & Recognition

**Screens (26):** E01–E03, E05–E07 · S01 · OP01–OP03 · AP01–AP05 · EV01–EV06 · P24–P28.

**Flutter:** `features/explore`, `saved`, `opportunities`, `applications`, `events`, `recognition` (badges, rankings, points).

**Backend:** search service (eligibility-first filtering, cursor pagination, viewer-visible fields only, no "find all eligible athletes" route); `SearchProjectionService` (only writer of `athlete_profiles.search.*`); coach/recruiter directory reads; opportunities reads + creator routes (counterpart); application service (eligibility result recorded, scoped grant requested from M4's `AccessGrantService`, status history); `EligibilityService` (restricted JSON predicates; used by OP03 and EV03); events + registration (atomic capacity, waitlist, deadline); results ingestion job (calls M5's `create_from_event`); leaderboard build job; badge evaluation job; append-only points ledger; saved items.

**API:** `POST /athletes/search` · `GET /coaches`, `/coaches/{id}` · `GET /recruiters`, `/recruiters/{id}` · `GET/POST/PATCH /opportunities` (POST/PATCH = S-04) · `POST /opportunities/{id}/eligibility` · `POST /opportunities/{id}/applications` · `GET /me/applications`, `/applications/{id}` · `POST …/withdraw` · `PATCH …/status` (S-05) · `POST/DELETE /saved`, `GET /saved` · `GET/POST/PATCH /events` (S-02) · `POST/DELETE /events/{id}/register` · `GET /me/event-registrations` · `GET/POST /events/{id}/results` (POST = S-03) · `GET /leaderboards`, `/leaderboards/own-rank` · `GET /athletes/{id}/badges`, `/me/badges` · `GET /me/points`.

**Database:** opportunities, applications, saved_items, events, event_registrations, leaderboard_snapshots, badges, athlete_badges, points_ledger.

**Testing:** search p95 ≤ 800 ms on seeded data; hidden athletes absent *and uncounted*; binary-search attempt on a private field; eligibility exhaustive table; apply → grant → status → withdraw; last-seat race and waitlist; duplicate result publish (idempotent); tie ranking; rankings only opted-in + discoverable + verified; badge rules; points ledger append-only.

**Dependencies:** M4 `authorize()/project()`, `AccessGrantService`; M1 profile facts and sports config; M5 `metric_bests` read service and `create_from_event`; M2 `NotificationService.emit`, jobs.

**Can be consumed by:** M4 (messaging rule asks "has this athlete applied to this recruiter's opportunity?"), M1/M2 (badges, points on profile/dashboard), E04.

**Future Coach integration:** Recruiter-side opportunity and application management reuse `opportunities` and `applications` unchanged (the creator routes already exist as counterpart routes); the Admin/Event phase publishes events and results through the same routes.

**NOT responsible for:** profile data, performance/achievement writes, media/documents/verification, connections, coach links, access-grant storage, messaging, notifications storage, Home/Dashboard, any recruiter-side athlete discovery or shortlists, payments, sponsorship, advanced recommendations.

---

# 6. MEMBER 4 — COMPLETE MODULE

**Module name:** Messaging, Connections, Coach Links & Privacy Access (+ authorization core)

**Screens (14):** M01–M05 · C01, C02 · L01, L02 · PR01, PR06, PR07, PR08, PR09.

**Flutter:** `features/messages`, `connections`, `coach_links`, `privacy_access`.

**Backend:** authorization core (`viewer_context`, `authorize()`, `project()`, field registry with default-deny, `platform_config`, rate limiting); messaging service; connection and block logic; coach-link logic (ending a link revokes LINKED access immediately); `AccessGrantService`; privacy schema and view-as preview; seed CLI, fixtures and Dev Counterpart Console.

**Messaging rules (ADR-001, Phase 1):** 1-to-1, text only. Athlete ↔ verified coach with an accepted connection or active coach link; athlete ↔ verified recruiter with an accepted connection or an application to that recruiter's opportunity. Unverified coach/recruiter cannot start a conversation (may reply). Blocked or ended basis → read-only. Length from `platform_config.limits.message_max_chars` (default 1000), rate-limited. **No** group chat, calls, AI chat, disappearing messages, attachments, receipts or typing indicators.

**API:** `GET/POST /conversations`, `GET/POST /conversations/{id}/messages`, `POST …/read`, `PATCH …/mute`, `DELETE /conversations/{id}` (counterpart side = S-09) · `POST /connections` (S-08), `POST …/respond`, `…/block`, `…/unblock`, `GET /connections` · `GET /coach-links`, `POST /coach-links` (S-06), `…/approve`, `…/decline`, `…/end` · `POST /access-grants/requests` (S-10), `POST /access-grants`, `…/grant`, `…/revoke`, `GET /access-grants` · `GET /me/privacy/schema` · `GET /me/profile/preview?as=` · `devtools seed/reset/act` (S-13).

**Database:** connections, coach_athlete_links, access_grants, conversations, messages, platform_config.

**Testing:** role × relationship × privacy matrix (≥ 40 cases); every messaging pair (verified/unverified × linked/unlinked × blocked); user B reading A's conversation/link/grant (IDOR); ending a link revokes access; view-as equals real projection; connection note ≤ 140; one active/requested link per coach+athlete+sport; chat Flutter states (sending, failed, read-only).

**Dependencies:** M1 users/profile; M3 applications lookup (messaging rule); M2 emit and jobs; M5 verification state of coach/recruiter fixtures (via the real decision route).

**Can be consumed by:** every member (`project()`), M5 (link status for endorsement; grants for certificate share), M3 (grants for application scopes), M1 (privacy schema).

**Future Coach integration:** the relationship and grant model *is* the Coach/Recruiter access model. Coach UI will call the existing connections, links, grants and conversations routes with `X-Active-Role`; only the console stubs are replaced.

**NOT responsible for:** profile writes, performance, media/verification, search/opportunity/application logic, events, notifications storage, Home/Dashboard, group chat or calls. Other members must not add their own `authorize()` logic.

---

# 7. MEMBER 5 — COMPLETE MODULE

**Module name:** Sports Record, Evidence & Verification

**Screens (19):** P08–P14 · P17–P23 · V01–V05.

**Flutter:** `features/performance`, `achievements`, `media`, `documents`, `verification`, plus the shared resumable upload widget. Coach Endorsed display (badge, "Confirmed by your linked coach — not an official verification", hide, report) lives in P08/P09.

**Backend:** performance service (source set by the endpoint, never the client; edit resets endorsement/verification; verified entries immutable); derived metrics from sport config; `MetricValidator`; `metric_bests` rebuild job (tiers PUBLIC_AUTH / VERIFIED_PRO / FULL; `best_verified_value` counts verified only) and a read service for M3; achievements service; endorsement service; `create_from_event` (idempotent, called by M3's results job); media pipeline (validate → pre-signed upload → confirm → transcode/thumbnail job → moderation state → signed playback); documents (virus scan, OWNER-only identity, signed URL ≤ 5 min, audit on non-owner access); verification service (owner-derived target, one open request per target, history, outbox event) and `verification.apply` job calling owners' apply handlers (M1 identity/sport profile, M5 performance/achievement/documents); purge handlers; Docker, storage abstraction.

**API:** `POST/GET/PATCH/DELETE /performance…`, `GET /me/performance`, `GET /athletes/{id}/performance`, `…/stats` · `POST/GET/PATCH/DELETE /achievements…`, `GET /me/achievements`, `GET /athletes/{id}/achievements` · `POST /performance/{id}/endorse` and `POST /coach-links/{id}/performance` (S-07; path prefix is M4's but the resource is M5's) · `POST /media/upload-url`, `…/confirm`, `GET /me/media`, `GET/PATCH/DELETE /media/{id}`, `…/playback-url`, `GET /athletes/{id}/media` · `POST /documents/upload-url`, `…/confirm`, `GET /me/documents`, `GET/PATCH/DELETE /documents/{id}`, `GET …/url` · `POST /verification`, `GET /me/verification…`, `POST …/resubmit`, `GET /admin/verification`, `POST …/decide` (S-01), `POST /admin/media/{id}/moderate` (S-11), `POST …/takedown`.

**Database:** performance_entries, metric_bests, achievements, media, documents, verification_requests (binaries only in object storage).

**Testing:** derived metrics, lower-is-better, tier calculation, `metric_bests` rebuilt from scratch equals live data; unknown metric, wrong unit, client-sent `source`; MIME + magic bytes, spoofed extension, oversize, confirm without object, EICAR file; state machines (pending → in_review → verified | rejected | needs_info; verified → revoked with reason); athlete B fetching A's document/media; coach/recruiter fetching an identity document rejected *before* storage access; expired signed URL; Coach Endorsed never becomes Verified; tier leakage; BOLA sweep of every id-bearing route; resumable-upload Flutter tests.

**Dependencies:** M1 profile/`ProfileCacheService` and sports config; M4 `authorize()/project()`, coach-link status, grants (certificate scope); M2 jobs, notifications, renderer, design system.

**Can be consumed by:** M1 (profile highlights, photo, identity badge), M3 (eligibility, rankings, event records), M2 (Home/Dashboard), M4 (verification state), E04.

**Future Coach integration:** Coach endorsement, coach-entered performance and Admin verification decisions are already routes on M5's resources (counterpart stubs S-01, S-07, S-11). Coach/Admin phases add UI only; the verification state machine and visibility tiers are reused as-is.

**NOT responsible for:** authentication, profile/onboarding, search, connections/links/grants, opportunities/applications, events and results screens, rankings/badges/points, messaging, notifications, Home/Dashboard, any admin verification UI or guardian/consent flow.

---

# 8. FLUTTER FILE OWNERSHIP

One app, one repo. Each member edits only their own folders; registration of routes happens in each feature's own `routes.dart` (one registry line in M1's router, no other shared-file edits).

| Path | Owner |
|---|---|
| `lib/app/` (router, shell, 5-tab navigation, route guards) | M1 |
| `lib/core/network/`, `lib/core/theme/`, `lib/core/design_system/`, `lib/core/widgets/` (states), `lib/core/config_form/` | M2 |
| `lib/core/deeplink/` | M2 |
| `lib/features/auth/`, `onboarding/`, `profile/` (incl. `viewer/`), `sportsz_id/`, `privacy_settings/`, `account/` | M1 |
| `lib/features/home/`, `dashboard/`, `notifications/`, `settings/`, `help/` | M2 |
| `lib/features/explore/`, `saved/`, `opportunities/`, `applications/`, `events/`, `recognition/` | M3 |
| `lib/features/messages/`, `connections/`, `coach_links/`, `privacy_access/` | M4 |
| `lib/features/performance/`, `achievements/`, `media/`, `documents/`, `verification/`, `lib/core/upload/` | M5 |

Each feature folder: `*_screen.dart`, `*_controller.dart`, `*_repository.dart`, `models/`, `widgets/`, `routes.dart`, `test/`. Repositories call the API client only; no feature imports another feature's folder, only that feature's published repository interface.

---

# 9. API OWNERSHIP

Exactly one owner per API; everyone else is a consumer. Full method/auth/authorization tables are in v2.1 §3 and move with the route.

| API group | Owner | Consumers |
|---|---|---|
| `/auth/*`, `/me` (GET, PATCH), `/me/roles/athlete`, `/sports*`, `/organizations*` | M1 | all |
| `/me/profile/athlete*`, `GET /athletes/{id}`, `/me/sportsz-id*`, `/id/{id}` | M1 | all |
| `/me/home`, `/me/dashboard` | M2 | — |
| `/me/notifications*`, `/me/notification-prefs`, `/me/devices` | M2 | all (emit via service) |
| `/reports`, `/me/reports`, `/admin/reports/*` (S-12) | M2 | M5 (report from P09) |
| `DELETE /me`, `/me/cancel-deletion`, `/me/data-export*`, `/dev/jobs/run-due` (S-14) | M2 | M1, M3, M4, M5 (purge handlers) |
| `/athletes/search`, `/coaches*`, `/recruiters*` | M3 | — |
| `/opportunities*` (incl. S-04), `/applications*`, `/me/applications` (S-05), `/saved*` | M3 | M4 (messaging rule) |
| `/events*`, `/me/event-registrations` (S-02, S-03) | M3 | M5 (results → records) |
| `/leaderboards*`, `/athletes/{id}/badges`, `/me/badges`, `/me/points` | M3 | M1, M2 |
| `/conversations*` (S-09) | M4 | — |
| `/connections*` (S-08), `/coach-links*` relationship routes (S-06) | M4 | M5 (link status), M1/M3 (state) |
| `/access-grants*` (S-10) | M4 | M3, M5 |
| `/me/privacy/schema`, `/me/profile/preview` | M4 | M1 (privacy screens) |
| `/performance*`, `/me/performance`, `/athletes/{id}/performance|stats` | M5 | M1, M2, M3 |
| `/achievements*`, `/me/achievements`, `/athletes/{id}/achievements` | M5 | M1, M2 |
| `/performance/{id}/endorse`, `/coach-links/{id}/performance` (S-07) | M5 | M4 (link check) |
| `/media*`, `/documents*`, `/athletes/{id}/media` | M5 | M1 (photo), M3, M4 |
| `/verification`, `/me/verification*`, `/admin/verification*` (S-01), `/admin/media/*` (S-11) | M5 | M1, M2 |

**Two deliberate path-sharing cases (different owners, no shared handler):** `/me` — M1 owns GET/PATCH, M2 owns DELETE in a separate router file; `/coach-links/{id}/performance` — path prefix is M4's, the resource and handler are M5's.

**Contract-first template (required in `docs/api/<module>.yaml` before a screen starts):**
`METHOD · ENDPOINT · AUTH · AUTHORIZATION · REQUEST · RESPONSE · ERRORS · COLLECTION · OWNER · DEPENDENCIES`

Example — `GET /athletes/{sportsz_id}` · Auth: Bearer · Authz: `authorize()` + `project()`, block-aware · Request: path id · Response: `{data: AthleteProfileView, meta}` (fields depend on viewer) · Errors: 401, 403 (uniform with 404 when hidden), 404 · Collection: athlete_profiles · Owner: M1 · Depends on: M4 `project()`.

Conventions (unchanged): `/v1`, envelope `{data, meta{next_cursor, request_id}}`, errors `{error{code, message, details[], request_id}}`, cursor pagination, Pydantic `extra=forbid`, server-owned fields never accepted, athlete routes by `sportsz_id`, coach/recruiter/org routes by `public_id`. APIs are resources/actions, never screens.

---

# 10. BACKEND OWNERSHIP

Layout: `app/modules/<module>/{router,service,repository,schemas}.py` + `tests/`. A module's repository is the only code that touches its collections.

| Module path | Owner | Key services |
|---|---|---|
| `app/core/` (envelope, errors, config, logging, auth dependency, Mongo connection, index runner) | M1 | Firebase `AuthProvider` |
| `app/core/jobs`, `audit`, `notify` | M2 | job runner/outbox, `AuditService.append`, `NotificationService.emit` |
| `app/core/authz`, `ratelimit`, `platform_config` | M4 | `viewer_context`, `authorize()`, `project()`, field registry |
| `app/core/storage` | M5 | storage abstraction, signed URLs, file validation |
| `app/modules/identity` (users, profile, sports, sportsz_id, organizations) | M1 | `ProfileCacheService`, ID generator |
| `app/modules/home_notifications` (home, dashboard, notifications, reports, account lifecycle) | M2 | composition, push dispatch, purge orchestration |
| `app/modules/discovery` (search, directories, saved) | M3 | `SearchProjectionService` |
| `app/modules/opportunities` (opportunities, applications) | M3 | `EligibilityService` |
| `app/modules/events` (events, registrations, results) | M3 | results ingestion |
| `app/modules/recognition` (leaderboards, badges, points) | M3 | leaderboard job, badge job, ledger |
| `app/modules/relationships` (connections, coach links, grants) | M4 | `AccessGrantService` |
| `app/modules/messaging` | M4 | messaging permission function |
| `app/modules/sports_record` (performance, achievements) | M5 | `MetricValidator`, `metric_bests` job + read service, `create_from_event`, endorsement |
| `app/modules/evidence` (media, documents) | M5 | media pipeline, scan |
| `app/modules/verification` | M5 | state machine, `verification.apply` job |
| `app/devtools/` (seed, reset, act, `/dev/*`) | M4 (each owner adds own fixtures); `/dev/jobs/run-due` M2 | gated by `DEV_TOOLS_ENABLED` and `ENV≠production` |

**Cross-module writes happen only through the owner's service:** `ProfileCacheService` (M1), `SearchProjectionService` (M3), `create_from_event` (M5), `AccessGrantService` (M4), `NotificationService.emit` and `AuditService.append` (M2).

---

# 11. DATABASE / COLLECTION OWNERSHIP

| Collection | Owner | Written by others only via |
|---|---|---|
| users, athlete_profiles, sports, sports_ids, organizations, organization_members | M1 | `ProfileCacheService` (verification summary), `SearchProjectionService` (`search.*`) |
| notifications, feedback_reports, jobs, audit_logs | M2 | `NotificationService.emit`, `AuditService.append`, job enqueue |
| opportunities, applications, saved_items | M3 | — |
| events, event_registrations | M3 | — |
| leaderboard_snapshots, badges, athlete_badges, points_ledger | M3 | — |
| connections, coach_athlete_links, access_grants | M4 | `AccessGrantService` |
| conversations, messages | M4 | — |
| platform_config | M4 | read-only for all |
| performance_entries, metric_bests, achievements | M5 | `create_from_event` |
| media, documents, verification_requests | M5 | verification apply handlers |

No new collection may be created without a PR to this table. No `*_v2`, `user_details`, `athlete_details`, or role-specific copies of athlete entities. No guardian collections.

---

# 12. SHARED FOUNDATION OWNERSHIP

Created **once**. Temporary ownership of a foundation item does not mean owning the screens that use it.

| Item | Owner | Needed by |
|---|---|---|
| FastAPI skeleton, router registry, env config, request-id logging | M1 | S0 day 3 |
| Common API envelope and error format | M1 | S0 day 3 |
| Firebase token validation dependency | M1 | S0 day 3 |
| Mongo connection, index/migration runner | M1 | S0 |
| Flutter router, shell, 5-tab bar, route guards | M1 | S0–S1 |
| Flutter architecture (Riverpod, feature folders), API client, interceptors | M2 | S0 |
| Design tokens, theme, typography, buttons, inputs, cards, chips, verification badge, loading/empty/error widgets | M2 | S0–S1 |
| `ConfigFormRenderer` | M2 | S1 |
| Jobs/outbox, `AuditService`, `NotificationService.emit`, deep-link router | M2 | S0 |
| CI pipeline | M2 | S0 day 3 |
| `viewer_context`, `authorize()`, `project()` + field registry, `platform_config`, rate limiting | M4 | S1–S2 |
| Seed CLI, fixture actors, Dev Counterpart Console | M4 | S0 baseline |
| Docker compose (Mongo replica set, MinIO, ffmpeg, ClamAV), storage abstraction, signed URLs, file validation | M5 | S0 day 3 |
| OpenAPI generation and `docs/api/` folder convention | each owner for own module | per screen |

Fixtures: ATHLETE_1/2, COACH_V/U, RECR_V/U, ORG_V, ADMIN, USER_BLOCKED; verified states are produced through the real decision route (S-01), never directly in the database.

---

# 13. CROSS-SCREEN DEPENDENCIES

Screen A consumes Screen B's documented API/service; it never duplicates B's collection access.

| Consumer | Consumes | From | Needed by |
|---|---|---|---|
| All | `/me`, `GET /athletes/{id}`, `/sports*`, envelope, auth dependency | M1 | S0–S2 |
| All | `authorize()/project()` | M4 | S1–S2 |
| All Flutter | design system, renderer | M2 | S0–S1 |
| All emitters | `NotificationService.emit`, `AuditService`, jobs | M2 | per sprint |
| M1 O01/P03 | profile-photo upload | M5 | S1 |
| M1 P01, E04 | performance/achievement/media reads; badges | M5; M3 | S3 |
| M1 PR02/03/05 | `/me/privacy/schema` | M4 | S2 |
| M1 PR02 | search rebuild trigger | M3 (via M2 job enqueue) | S4 |
| M3 OP03, EV03 | profile facts; `metric_bests` read service | M1; M5 | S4–S6 |
| M3 AP04 | `AccessGrantService` | M4 | S5 |
| M3 EV06 job | `create_from_event` | M5 | S6 |
| M3 P26/P27 | `metric_bests` read service | M5 | S6 |
| M3 badge job | verified records, completion | M5; M1 | S6 |
| M4 messaging | applications lookup | M3 | S5 |
| M5 endorsement | coach-link status | M4 | S3 |
| M5 verification apply | identity/sport-profile handlers | M1 | S4 |
| M5 P23 | certificate grant scope | M4 | S4 |
| M2 H01/D01 | every owner's read APIs | M1, M3, M4, M5 | S2 onward |
| M2 purge | each owner's purge handler | M1, M3, M4, M5 | S7 |

---

# 14. GIT BRANCH STRUCTURE

```
main            (release only)
└─ develop      (integration; always green)
   ├─ foundation/backend-core          M1
   ├─ foundation/flutter-core          M2
   ├─ foundation/authz-core            M4
   ├─ foundation/infra-storage         M5
   ├─ feature/member1-identity-profile
   ├─ feature/member2-home-notifications
   ├─ feature/member3-explore-opportunities
   ├─ feature/member4-messages-relationships
   └─ feature/member5-sports-record-verification
```
Sub-branches per screen group, e.g. `feature/member3-events`. Flow: feature branch → Pull Request → review → `develop` → release to `main`. Never push feature work to `main`. `CODEOWNERS` maps each folder in §8/§10 to its owner; a PR touching another owner's folder or `docs/api/<other>.yaml` needs that owner's approval. Contract changes are merged *before* the code that depends on them.

---

# 15. INTEGRATION STRATEGY

Order: shared foundation → API contracts → each vertical slice → local test → cross-screen integration → authentication test → authorization test → Athlete integration → end-to-end. Every sprint merges completed screens into `develop` and ends with a review on the real API and MongoDB.

| Sprint | M1 | M2 | M3 | M4 | M5 |
|---|---|---|---|---|---|
| S0 Foundation | backend core, auth dependency, sports seed, router + guards | Flutter core, design system, jobs/audit/notify, CI | contracts for search/opps/apps/events/recognition; eligibility spec | authz core v0, platform_config, seed CLI, fixtures | Docker/storage/signed URLs, contracts for record/evidence/verification |
| S1 Auth + onboarding | A01–A08, O01, O02, O05, O06, `/auth/*`, `/me` | renderer, components final, devices API, Home shell | coach/recruiter directory reads (E05, E06), E01 shell | real `viewer_context`, `GET /me` via `project()`, BOLA test template | profile-photo upload pipeline, media/document models |
| S2 Profile | P01–P07, P15–P16, O07–O11, I01–I04, `ProfileCacheService`, E04 v1 | Home v1, N01 + notification APIs, ST01, HS01–HS07 | `SearchProjectionService`, OP01–OP02, EV01–EV02 reads | field overrides, privacy schema, C01–C02, profile-read matrix | media pipeline, P17–P23 |
| S3 Performance | profile highlights, completion weights, ST02, ST03, X01 | D01 v1 on real APIs | E01–E03 search v1, E07, S01 | L01–L02 coach links (S-06), grants backend | P08–P14, `metric_bests`, endorsement (S-07) |
| S4 Verification | apply handlers, ID badge, PR02/03/05 | N02, ST04, verification notification types | `EligibilityService`, OP03, opportunities full (S-04) | M01–M05 messaging backend + UI | V01–V05, apply job, S-01, S-11 |
| S5 Opportunities + messaging | org picker, block-aware profile read | ST05/ST06 skeleton, deep-link coverage | AP01–AP05, applications (S-05), AP04 with M4 | messaging done, PR01, PR08, PR09, PR06–PR07 UI | document expiry, takedown, metric filters for search |
| S6 Events + recognition | re-auth, logout-all, fixture builder v2 | D01 final | EV03–EV06, results job (S-02, S-03), leaderboards, badges, points | permission matrices | `create_from_event`, record links |
| S7 Management | purge handler | delete/export end-to-end, reports outcome (S-12) | purge handler | purge handler, blocked/grants polish | purge handler, signed-URL audit |
| S8 Exit gate | full journey, audits, fixes by every member | | | | |

This replaces v2.1 §9 for assignment purposes; points should be re-estimated in Sprint Planning.

---

# 16. TESTING RESPONSIBILITY

Each owner tests their own slice. A screen is done only when all of this is checked:
Flutter UI ✓ · API integration ✓ · endpoint ✓ · MongoDB ✓ · authentication ✓ · authorization with negative tests ✓ · validation ✓ · loading / empty / error / success states ✓ · unit and API tests ✓ · integration test on the real API and MongoDB ✓ · no duplicate model ✓ · no test-only logic ✓ · works with real authentication ✓ · matches the documented contract ✓ · future-compatible ✓ · docs updated ✓ · reviewed and merged to `develop` ✓.

| Test type | Who |
|---|---|
| Unit, API, Flutter, integration for a screen | its owner |
| Role × relationship × privacy matrix, projection snapshot tests | M4 maintains; every owner adds cases for their resource |
| BOLA sweep of id-bearing routes | each owner for own routes; M5 sweeps media/docs/verification, M4 sweeps connections/links/grants/conversations |
| Search performance (p95 ≤ 800 ms) | M3 |
| Messaging permission matrix | M4 |
| Stub conformance (a stub never skips authorization) | stub owner |
| Cross-screen E2E, accessibility, UI audit | all in S8; M2 leads UI audit |

---

# 17. FUTURE COACH / RECRUITER / ADMIN INTEGRATION CHECKLIST

Flow for any resource:

```
Athlete app → GET /athletes/{id}  → same athlete_profiles → project(role = athlete)   → athlete view
Coach UI    → GET /athletes/{id}  → same athlete_profiles → authorize + project(coach)    → coach-safe view
```

| Reuse | Existing route / service | Coach | Recruiter | Admin |
|---|---|---|---|---|
| Athlete profile | `GET /athletes/{id}` (M1) | linked/permitted fields | discoverable/public fields | audited admin operations |
| Sports, performance, stats, achievements | `/athletes/{id}/…` (M5) | by tier | verified/public tier | audited |
| Media, documents | `/athletes/{id}/media`, `/documents/{id}/url` (M5) | approved media; identity docs never | approved media; certificates only via grant | audited |
| Verification | `/admin/verification*` (M5) | endorse only (never Verified) | — | decide, revoke |
| Connections, coach links, grants | M4 routes | initiate if verified | initiate if verified | — |
| Opportunities, applications | M3 routes | create if verified | create/manage | moderate |
| Events, results | M3 routes | — | — | publish |
| Messages | M4 routes | verified, linked/connected | verified, connected/applied | — |
| Notifications, rankings, badges | M2, M3 | read | read | — |

Checklist before Coach starts:
- [ ] Field registry has role columns for coach, recruiter, admin, default-deny
- [ ] `X-Active-Role` header handled in `viewer_context`
- [ ] Counterpart routes (S-01…S-12) work with the real tokens of fixtures
- [ ] No athlete-only assumption in any collection; no role-specific copy of athlete data
- [ ] No Flutter-only state for anything that must persist
- [ ] Every API is a resource/action, not a screen
- [ ] Stub register published with replacement points; console tools documented
- [ ] Coach UI needs no new athlete collection and no change to athlete routes

---

# 18. FINAL OVERLAP AUDIT

| Check | Result |
|---|---|
| Every Athlete screen has exactly one owner | ✅ 113 screens, 38+16+26+14+19 |
| No screen has two primary owners | ✅ |
| No two members own the same API | ✅ one flagged path-sharing case (`/me` GET/PATCH vs DELETE) and one prefix case (`/coach-links/{id}/performance`), each with separate handlers |
| No two members own the same collection | ✅ 32 collections, one owner each; cross-writes only via named services |
| No duplicate models / business logic | ✅ `EligibilityService` (M3) used by OP03 and EV03; rankings read M5's `metric_bests`; Home/Dashboard store nothing |
| No duplicate auth / authorization logic | ✅ auth dependency M1, `authorize()/project()` M4 only |
| Shared infrastructure identified | ✅ §12 |
| Cross-screen dependencies documented | ✅ §13 |
| Future Coach / Recruiter / Admin can reuse Athlete data | ✅ §17 |
| Athlete data not coupled to a Flutter screen | ✅ |
| APIs are resources, not screens | ⚠️ `/me/home` and `/me/dashboard` are screen-shaped composed reads, kept because v2.1 specifies them; see Open item 2 |
| No Phase-2 feature entered Athlete Phase | ✅ no social feed, followers, group chat, calls, AI chat, OpenCV, payments, sponsorship, role switcher, Coach/Recruiter/Admin UI |
| Messaging stays Phase 1 | ✅ M4, ADR-001 |
| Rankings / Badges / Points stay Phase 1 | ✅ M3 |
| No guardian / minor functionality | ✅ |
| Five members can develop independently | ✅ after S0 contracts and fixtures |
| Final integration without restructuring | ✅ one app, one backend, one DB, one auth, one authz |

---

# OPEN ITEMS (decide in Sprint 0)

1. **Member numbering changed vs v2.1.** Map real people to M1–M5 before S0. The sprint points in v2.1 §2/§9 do not carry over.
2. **`/me/home` and `/me/dashboard`** are composed, screen-shaped read models (from the source). Keep as specified, or replace with direct resource calls from Flutter. Recommendation: keep, owned by M2, athlete-scoped only.
3. **Source gaps (not invented):** where coach/recruiter directory profiles live (E05/E06 say "seeded profiles" but §7 has no collection; follow Arch v1.1) · where device tokens are stored (`/me/devices`) · whether M02 needs a server search route (assumed client-side) · logout-all-devices / session-revoke route for ST03 · exact content of ST04 and individual HS01–HS07 names (not in v2.1; confirm in the UI/UX spec) · PR04 absent.
4. **Critical path:** M4's authz core (S1–S2) and M1's conventions (S0) block everyone; protect those sprints.
5. **Relief valve** if M3 overloads: P24–P28 + badge/points job to M2.
6. **v2.1 open decisions still apply:** D2 additions (`POST /admin/media/{id}/moderate`, `/me/verification/{id}/resubmit`, `/connections/{id}/unblock`, `/coach-links/{id}/decline`, `POST /access-grants`, `/documents/{id}/confirm`), athlete-initiated coach link, and the legal review of removing all minor handling before launch.
