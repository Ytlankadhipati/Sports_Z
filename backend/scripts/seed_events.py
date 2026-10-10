"""Development-only seed data for the M3 athlete Events flow.

Run from backend with the configured MongoDB connection:
    python -m scripts.seed_events
"""

from datetime import datetime, timedelta, timezone

from app.modules.events.repository import upsert_seed_event


def main() -> None:
    now = datetime.now(timezone.utc)
    events = [
        {
            "public_id": "evt_seed_athletics_01",
            "title": "Lucknow District Athletics Trials",
            "sport_id": "athletics",
            "description": "Track and field trials for district athletes.",
            "location": "Lucknow, Uttar Pradesh",
            "starts_at": now + timedelta(days=18),
            "registration_deadline": now + timedelta(days=10),
            "capacity": 50,
            "registered_count": 12,
            "waitlist_count": 0,
            "status": "upcoming",
        },
        {
            "public_id": "evt_seed_wrestling_full",
            "title": "Varanasi Open Wrestling Meet",
            "sport_id": "wrestling",
            "description": "Open wrestling meet. This event is full and accepts waitlist registrations.",
            "location": "Varanasi, Uttar Pradesh",
            "starts_at": now + timedelta(days=28),
            "registration_deadline": now + timedelta(days=20),
            "capacity": 24,
            "registered_count": 24,
            "waitlist_count": 0,
            "status": "upcoming",
        },
        {
            "public_id": "evt_seed_football_deadline",
            "title": "Kanpur Football Skills Festival",
            "sport_id": "football",
            "description": "A regional football skills festival for youth teams.",
            "location": "Kanpur, Uttar Pradesh",
            "starts_at": now + timedelta(days=14),
            "registration_deadline": now - timedelta(days=1),
            "capacity": 32,
            "registered_count": 11,
            "waitlist_count": 0,
            "status": "upcoming",
        },
        {
            "public_id": "evt_seed_badminton_01",
            "title": "State Junior Badminton Open",
            "sport_id": "badminton",
            "description": "Singles and doubles brackets for junior players.",
            "location": "Jaipur, Rajasthan",
            "starts_at": now + timedelta(days=35),
            "registration_deadline": now + timedelta(days=25),
            "capacity": 96,
            "registered_count": 41,
            "waitlist_count": 0,
            "status": "upcoming",
        },
        {
            "public_id": "evt_seed_volleyball_01",
            "title": "Inter-College Volleyball Cup",
            "sport_id": "volleyball",
            "description": "A two-day inter-college volleyball tournament.",
            "location": "Bhopal, Madhya Pradesh",
            "starts_at": now + timedelta(days=45),
            "registration_deadline": now + timedelta(days=32),
            "capacity": 20,
            "registered_count": 7,
            "waitlist_count": 0,
            "status": "upcoming",
        },
        {
            "public_id": "evt_seed_past_01",
            "title": "Delhi Basketball Invitational",
            "sport_id": "basketball",
            "description": "Completed invitational tournament archive entry.",
            "location": "New Delhi",
            "starts_at": now - timedelta(days=20),
            "registration_deadline": now - timedelta(days=30),
            "capacity": 16,
            "registered_count": 16,
            "waitlist_count": 0,
            "status": "completed",
        },
    ]
    for event in events:
        upsert_seed_event(event)
    print(f"Events seed complete: {len(events)} development events upserted.")


if __name__ == "__main__":
    main()
