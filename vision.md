📍 MapTag BF – Full Rollout Roadmap
🎯 Vision
Give every home, shop, and service point in Burkina Faso a permanent, digital address that works offline or online and can be used for deliveries, transport, and emergency services — without needing a massive field-mapping team.
PHASE 0 — Foundation (Weeks 0–2)
Goal: Set technical, branding, and operational groundwork.
Tasks
Finalize address code format: BF-CITY-GRID-XXXX (+ optional unit suffix).
Design trust levels: Auto / AI-Verified / Pro-Verified.
Create brand & visual identity: logo, colors, QR sticker style.
Secure domain (e.g., maptag.bf) + hosting.
Partner outreach:
Logistics companies
Moto-taxi unions
Delivery apps
Emergency service organizations
PHASE 1 — Core App + AI Verification (Weeks 3–6)
Goal: Launch MVP with AI-powered self-verification.
Features
Create Address
Capture GPS (offline-capable).
Generate unique code.
Add place name + category.
Take building photo.
Save offline if no internet.
AI Verification
Duplicate detection (20–30m radius).
Photo-to-satellite match.
Building footprint recognition.
Assign confidence score:
90% = AI-Verified (green badge)
70–90% = AI-Verified (yellow badge, possible follow-up)
<70% = Needs recheck
Share Address
QR code.
Short link.
SMS code.
PHASE 2 — Business & Pro Addresses (Weeks 7–10)
Goal: Get small businesses onboard + start monetizing.
Features
Business category, opening hours, phone, Moov/Orange Money number.
Upload logo & storefront photo.
Optional Pro badge via:
Document upload (trade license)
Remote AI verification against registry
Business search in app.
PHASE 3 — Partner API & Integrations (Weeks 11–14)
Goal: Make addresses usable in other apps.
Features
API endpoints:
GET /places/{code} → Returns GPS, name, notes.
POST /places → Create address (partner app integration).
Integrations:
Logistics & delivery companies (drop-off accuracy).
Ride-hailing / moto-taxi apps.
Emergency service dispatch.
PHASE 4 — Offline Sync + Mesh Networking (Weeks 15–18)
Goal: Ensure addresses work without internet.
Features
Local database of nearby addresses.
Bluetooth/Wi-Fi Direct syncing between devices.
Conflict resolution for updates.
SMS fallback for code lookup.
PHASE 5 — Pilot Launch (Weeks 19–24)
Goal: Test in real-world environment.
Target Zones
Ouagadougou: 2 neighborhoods (urban).
Bobo-Dioulasso: 1 neighborhood (urban).
One rural market town.
KPIs
5,000+ addresses created.
90% AI-verified.
<5% need agent follow-up.
2–3 business API integrations live.
PHASE 6 — Community Growth & Gamification (Months 7–9)
Goal: Rapid address creation via public participation.
Tactics
Neighborhood challenges: “Map your secteur, win prizes.”
Leaderboards in app.
Small mobile money or data rewards for verified mapping.
Social media campaigns + local radio spots.
PHASE 7 — Nationwide Rollout (Months 10–18)
Goal: Become Burkina Faso’s de facto addressing standard.
Steps
Partner with municipal authorities for official recognition.
Expand to:
All major cities.
Major transport corridors.
Rural trading hubs.
Launch agent verification program for low-confidence tags.
PHASE 8 — Monetization Scaling (Months 12–24)
Goal: Achieve sustainable recurring revenue.
Revenue Streams
Free for individuals (max 2 addresses).
Pro Plan for Businesses (~5,000 CFA/year):
Logo, opening hours, Pro badge.
Search priority.
API for Partners:
Per active driver/device.
Flat monthly for unlimited lookups.
Printed stickers & signage at cost+margin.
TECH STACK
Frontend: Flutter (offline-first, FR/local language support).
Backend: Node.js + PostgreSQL + Redis (geospatial queries).
AI Layer: TensorFlow Lite or PyTorch Mobile for on-device verification.
Maps: Mapbox with offline vector tiles.
Offline Storage: RealmDB or SQLite.
Sync: Background service with conflict handling.
RISKS & MITIGATION
Duplicate addresses: Strong duplicate detection + claim flow.
Low adoption: Partner with delivery/taxi operators to drive user need.
Rural onboarding: Use community leaders & NGOs for outreach.
EXPECTED IMPACT IN 12 MONTHS
Addresses created: 200,000+
Businesses onboard: 10,000+
API partners: 15+
AI verification success rate: 85–90%
Revenue: $50–100K/year recurring from Pro & API.
