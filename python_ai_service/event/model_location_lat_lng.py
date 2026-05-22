import uuid

from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy import Column, String, TIMESTAMP, Float

Base = declarative_base()
MODEL_CACHE = {}

def create_location_lat_lng_model(table_name: str):
    if table_name in MODEL_CACHE:
        return MODEL_CACHE[table_name]
    model = type(
        f"Event_{table_name}",  # class 名稱
        (Base,),
        {
            "__tablename__": table_name,
            "__table_args__": {"extend_existing": True},  
            "id": Column(String, primary_key=True, default=lambda: str(uuid.uuid4())),
            "country": Column(String),
            "city": Column(String),
            "location": Column(String),
            "lat": Column(Float),
            "lng": Column(Float),
            "created_at": Column(TIMESTAMP(timezone=True)),
        }
    )
    MODEL_CACHE[table_name] = model
    return model