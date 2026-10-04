"""Dev-only seed data. Run from backend folder: python -m scripts.seed_m3"""
from datetime import datetime, timedelta

from app.core.database import db

now = datetime.utcnow()

opportunities = [
    {"public_id": "opp_001", "title": "State Athletics Trials 2026", "type": "trial", "sport_id": "athletics",
     "organization_name": "UP Athletics Association", "location": "Lucknow", "status": "open",
     "deadline": now + timedelta(days=20), "description": "Open trials for 100m, 200m and long jump.",
     "eligibility_summary": "Age 14 to 19. Athletics selected as a sport."},
    {"public_id": "opp_002", "title": "Rural Talent Scholarship", "type": "scholarship", "sport_id": "wrestling",
     "organization_name": "Khelo Foundation", "location": "Varanasi", "status": "open",
     "deadline": now + timedelta(days=35), "description": "Full training scholarship for wrestlers.",
     "eligibility_summary": "Age 16 to 22. Wrestling selected as a sport."},
    {"public_id": "opp_003", "title": "Junior Football Camp", "type": "camp", "sport_id": "football",
     "organization_name": "City Football Academy", "location": "Kanpur", "status": "open",
     "deadline": now + timedelta(days=10), "description": "Weekend development camp.",
     "eligibility_summary": "Age 12 to 17."},
    {"public_id": "opp_004", "title": "Sports Coach Assistant", "type": "job", "sport_id": "athletics",
     "organization_name": "BBD Sports Club", "location": "Lucknow", "status": "closed",
     "deadline": now - timedelta(days=5), "description": "Assistant coach position.",
     "eligibility_summary": "Age 21 and above."},
]

events = [
    {"public_id": "evt_001", "title": "District 100m Sprint Meet", "sport_id": "athletics", "location": "Lucknow",
     "starts_at": now + timedelta(days=15), "registration_deadline": now + timedelta(days=10),
     "capacity": 50, "registered_count": 12, "status": "upcoming", "description": "District level sprint meet."},
    {"public_id": "evt_002", "title": "Kushti Open Dangal", "sport_id": "wrestling", "location": "Varanasi",
     "starts_at": now + timedelta(days=30), "registration_deadline": now + timedelta(days=25),
     "capacity": 32, "registered_count": 32, "status": "upcoming", "description": "Full event, waitlist testing ke liye."},
    {"public_id": "evt_003", "title": "Inter-School Football Cup", "sport_id": "football", "location": "Kanpur",
     "starts_at": now - timedelta(days=20), "registration_deadline": now - timedelta(days=30),
     "capacity": 16, "registered_count": 16, "status": "completed", "description": "Finished event."},
]

for o in opportunities:
    db["opportunities"].update_one({"public_id": o["public_id"]}, {"$set": o}, upsert=True)
for e in events:
    db["events"].update_one({"public_id": e["public_id"]}, {"$set": e}, upsert=True)

db["opportunities"].create_index("public_id", unique=True)
db["events"].create_index("public_id", unique=True)
print(f"Seeded {len(opportunities)} opportunities and {len(events)} events.")