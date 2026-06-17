from dotenv import load_dotenv
import os
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

load_dotenv()

#DB_URL = os.getenv("DB_URL")
#DB_URL = "postgresql://postgres.ccktdpycnferbrjrdtkp:QN4uJPxHzWR64e2u@aws-0-ap-southeast-1.pooler.supabase.com:5432/postgres"
DB_URL = "postgresql://sa:sa@localhost:5432/life_pilot"
engine = create_engine(DB_URL)
SessionLocal = sessionmaker(bind=engine)