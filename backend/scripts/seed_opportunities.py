"""Development-only seed data for paginated Opportunities UI checks.

Run from the backend directory after seed_sports_catalog.py:
    python -m scripts.seed_opportunities
"""

from datetime import datetime, timedelta, timezone

from app.modules.opportunities.repository import upsert_seed_opportunity


# public_id, title, type, sport_id, organization, city, deadline offset,
# status, description, eligibility summary. Order is stable by design.
_SEED_ROWS = [
    ("opp_seed_001", "National Athletics Sprint Trials", "trial", "athletics", "SAI Regional Centre", "Lucknow", 21, "open", "Open trials for sprint and relay events at the regional centre.", "Age 15 to 22. Athletes should bring recent competition records and complete a fitness assessment."),
    ("opp_seed_002", "UP State Wrestling Scholarship", "scholarship", "wrestling", "Uttar Pradesh Sports Directorate", "Varanasi", 34, "open", "Annual support for promising freestyle and Greco-Roman wrestlers.", "Age 16 to 23. Applicants need district or state level wrestling experience."),
    ("opp_seed_003", "Junior Football Development Camp", "camp", "football", "Khelo India Training Centre", "Kanpur", 12, "open", "A two-week residential camp focused on ball control, tactics and match fitness.", "Age 13 to 18. Football experience and a basic medical fitness certificate are required."),
    ("opp_seed_004", "Badminton Academy Coach Assistant", "job", "badminton", "Prakash Padukone Sports Management", "Bengaluru", -4, "closed", "Assist senior coaches during junior group sessions and local tournaments.", "Applicants should be 20 or older and have played competitive badminton."),
    ("opp_seed_005", "Rajasthan Volleyball State Trials", "trial", "volleyball", "Rajasthan State Volleyball Association", "Jaipur", 18, "open", "Selection trials for the upcoming state junior squad.", "Age 14 to 19. Players should meet the association's fitness and height screening."),
    ("opp_seed_006", "Khelo India Basketball Scholarship", "scholarship", "basketball", "Lakshmibai National Institute of Physical Education", "Gwalior", 27, "open", "Training and education support for emerging basketball players.", "Age 16 to 21. Applicants need inter-school or district level playing experience."),
    ("opp_seed_007", "Hockey Skills Camp for Juniors", "camp", "field-hockey", "SAI National Centre of Excellence", "Bhopal", 9, "open", "A weekend camp covering fundamentals, small-sided games and conditioning.", "Age 12 to 17. Bring a stick, shin guards and proof of regular hockey practice."),
    ("opp_seed_008", "University Swimming Team Trials", "trial", "swimming", "Savitribai Phule Pune University", "Pune", -8, "closed", "Timed trials for the university swimming squad across freestyle and backstroke.", "Current university students with sanctioned meet times may apply."),
    ("opp_seed_009", "Archery Equipment Scholarship", "scholarship", "archery", "Tata Archery Academy", "Jamshedpur", 42, "open", "Equipment and coaching assistance for developing recurve archers.", "Age 14 to 20. Applicants should have competed at district level or above."),
    ("opp_seed_010", "Cricket Performance Analyst Intern", "job", "cricket", "National Cricket Academy", "Bengaluru", None, "open", "Support video tagging and match reports for youth training squads.", "Applicants should understand cricket scoring and be comfortable with spreadsheets and video review."),
    ("opp_seed_011", "Delhi Table Tennis Selection Trials", "trial", "table-tennis", "Delhi Table Tennis Association", "New Delhi", 15, "open", "Selection trials for state age-group teams in singles and doubles.", "Age 13 to 18. Players must bring their own racket and recent ranking details."),
    ("opp_seed_012", "Boxing High Performance Camp", "camp", "boxing", "Army Sports Institute", "Pune", -2, "closed", "A supervised camp for boxers preparing for the national season.", "Age 17 to 24. Medical clearance and previous sanctioned bout experience are required."),
    ("opp_seed_013", "Tennis Academy Training Grant", "scholarship", "tennis", "DLTA Tennis Centre", "New Delhi", 31, "open", "A term-long coaching grant for promising junior tennis players.", "Age 12 to 18. Applicants should submit match results and attend an on-court assessment."),
    ("opp_seed_014", "Weightlifting Talent Identification", "trial", "weightlifting", "SAI Training Centre", "Patiala", 23, "open", "Talent identification sessions for Olympic weightlifting categories.", "Age 15 to 20. Participants need a sports medical check and basic lifting experience."),
    ("opp_seed_015", "Football Club Community Coach", "job", "football", "Mohun Bagan Athletic Club", "Kolkata", 6, "open", "Lead beginner sessions and help organize weekend community fixtures.", "Applicants should have coaching certification or substantial playing experience."),
    ("opp_seed_016", "Kerala Athletics Monsoon Camp", "camp", "athletics", "Kerala Sports Council", "Thiruvananthapuram", 16, "open", "A track and field camp with event-specific coaching and recovery sessions.", "Age 14 to 21. Athletes should have completed at least one district meet."),
    ("opp_seed_017", "Wrestling Academy Residential Place", "scholarship", "wrestling", "Chhatrasal Stadium Akhara", "New Delhi", -11, "closed", "Residential coaching support for young wrestlers with competition potential.", "Age 15 to 20. District competition results and guardian consent are required."),
    ("opp_seed_018", "Badminton Doubles Open Trials", "trial", "badminton", "Telangana Badminton Association", "Hyderabad", None, "open", "Open doubles trials to identify pairs for the state training group.", "Age 15 to 22. Athletes may register individually and will be assessed with a partner."),
    ("opp_seed_019", "University Volleyball Coaching Fellow", "job", "volleyball", "University of Calcutta", "Kolkata", 29, "open", "Assist with practice planning and team preparation during the university season.", "Applicants should have a volleyball coaching qualification or state-level playing background."),
    ("opp_seed_020", "Basketball Youth Selection Camp", "camp", "basketball", "Tamil Nadu Basketball Association", "Chennai", -6, "closed", "A selection camp for youth squads with structured drills and practice games.", "Age 14 to 18. Prior district or school competition experience is expected."),
    ("opp_seed_021", "Haryana Hockey Junior Trials", "trial", "field-hockey", "Haryana Hockey Association", "Rohtak", 11, "open", "Trials for the state under-17 hockey development squad.", "Age 14 to 17. Players must bring complete playing kit and school identification."),
    ("opp_seed_022", "Swimming Talent Support Grant", "scholarship", "swimming", "GoSports Foundation", "Mumbai", 37, "open", "A one-year grant supporting coaching and competition travel for swimmers.", "Age 15 to 23. Applicants need recent meet results and a coach recommendation."),
    ("opp_seed_023", "Archery Range Assistant", "job", "archery", "Khelo India Centre", "Imphal", -1, "closed", "Help maintain the range and support supervised beginner sessions.", "Applicants should be 18 or older and understand range safety procedures."),
    ("opp_seed_024", "Cricket Girls Skills Camp", "camp", "cricket", "Madhya Pradesh Cricket Association", "Indore", 19, "open", "A development camp with batting, bowling and fielding sessions for girls.", "Age 13 to 19. Players should bring cricket kit and have played organized cricket."),
    ("opp_seed_025", "Table Tennis University Scholarship", "scholarship", "table-tennis", "Lovely Professional University", "Phagwara", 25, "open", "Tuition assistance and coaching access for competitive table tennis players.", "Applicants should be enrolled or eligible to enroll and provide tournament records."),
    ("opp_seed_026", "Boxing District Open Trials", "trial", "boxing", "Maharashtra Boxing Association", "Nagpur", 14, "open", "Open trials for district squad selection in youth and senior categories.", "Age 16 to 25. A valid medical fitness certificate is mandatory."),
    ("opp_seed_027", "Tennis Court Operations Assistant", "job", "tennis", "Karnataka State Lawn Tennis Association", "Bengaluru", None, "open", "Support court scheduling and junior tournament operations at the centre.", "Applicants should be 18 or older and comfortable working on event days."),
    ("opp_seed_028", "SAI Weightlifting Junior Trials", "trial", "weightlifting", "Sports Authority of India", "Kohima", -13, "closed", "Completed selection round for the regional junior weightlifting squad.", "Age 14 to 19. Candidates were assessed on technique, strength and movement quality."),
]


def main() -> None:
    now = datetime.now(timezone.utc)
    for (
        public_id,
        title,
        type_,
        sport_id,
        organization_name,
        location,
        deadline_days,
        status,
        description,
        eligibility_summary,
    ) in _SEED_ROWS:
        upsert_seed_opportunity(
            {
                "public_id": public_id,
                "title": title,
                "type": type_,
                "sport_id": sport_id,
                "organization_name": organization_name,
                "location": location,
                "deadline": (
                    now + timedelta(days=deadline_days)
                    if deadline_days is not None
                    else None
                ),
                "status": status,
                "description": description,
                "eligibility_summary": eligibility_summary,
            }
        )
    print(f"Opportunities seed complete: {len(_SEED_ROWS)} development opportunities upserted.")


if __name__ == "__main__":
    main()
