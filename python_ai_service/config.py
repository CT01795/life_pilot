from dotenv import load_dotenv
import os
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

load_dotenv()

#DB_URL = os.getenv("DB_URL")
DB_URL = "postgresql://postgres.ccktdpycnferbrjrdtkp:QN4uJPxHzWR64e2u@aws-0-ap-southeast-1.pooler.supabase.com:5432/postgres" #os.getenv("DB_URL")  # 從render環境變數取得
engine = create_engine(DB_URL)
SessionLocal = sessionmaker(bind=engine)