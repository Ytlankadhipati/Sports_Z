from pymongo import MongoClient
from dotenv import load_dotenv
import os

load_dotenv()

MONGO_URI = os.getenv("MONGO_URI")
MONGO_DB_NAME = os.getenv("MONGO_DB_NAME")

client = MongoClient(MONGO_URI)
db = client[MONGO_DB_NAME]

# Collections (A1 ownership: users, athletes, sports_ids)
users_collection = db["users"]
athletes_collection = db["athletes"]
sports_ids_collection = db["sports_ids"]