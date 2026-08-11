import os
from pathlib import Path

from dotenv import load_dotenv
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

load_dotenv(Path(__file__).with_name('.env'))

DB_URL = os.getenv('DB_URL')
if not DB_URL:
    raise RuntimeError('DB_URL is not configured')

engine = create_engine(DB_URL, pool_pre_ping=True)
SessionLocal = sessionmaker(bind=engine)
