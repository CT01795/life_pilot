import uuid

from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy import ARRAY, Column, String, Text, TIMESTAMP, Boolean, Numeric, Integer, Float
from sqlalchemy.dialects.postgresql import JSONB

Base = declarative_base()
MODEL_CACHE = {}

def create_event_model(table_name: str):
    if table_name in MODEL_CACHE:
        return MODEL_CACHE[table_name]
    if table_name == "recommended_event_url":
        model = type(
            f"{table_name}_model",  # ✅ class 名稱不要直接用 table_name
            (Base,),
            {
                "__tablename__": table_name,
                "__table_args__": {"extend_existing": True},  
                "master_url": Column(String, primary_key=True),
                "start_date": Column(TIMESTAMP(timezone=True), primary_key=True),
            }
        )
        MODEL_CACHE[table_name] = model
        return model
    if table_name == "recommended_events_favor":
        model = type(
            f"{table_name}_model",  # ✅ class 名稱不要直接用 table_name
            (Base,),
            {
                "__tablename__": table_name,
                "__table_args__": {"extend_existing": True},  
                "id": Column(String, primary_key=True, default=lambda: str(uuid.uuid4())),
                "is_like": Column(Boolean),
                "is_dislike": Column(Boolean),
                "account": Column(Text, primary_key=True),
            }
        )
    else:
        model = type(
            f"{table_name}_model",  # class 名稱
            (Base,),
            {
                "__tablename__": table_name,
                "__table_args__": {"extend_existing": True},  
                "id": Column(String, primary_key=True),
                "master_graph_url": Column(Text),
                "master_url": Column(Text),
                "start_date": Column(TIMESTAMP(timezone=True)),
                "end_date": Column(TIMESTAMP(timezone=True)),
                "start_time": Column(Text),
                "end_time": Column(Text),
                "city": Column(Text),
                "location": Column(Text),
                "name": Column(Text),
                "type": Column(Text),
                "description": Column(Text),
                "fee": Column(Text),
                "unit": Column(Text),
                "sub_events": Column(JSONB),
                "account": Column(Text),
                "repeat_options": Column(Text),
                "reminder_options": Column(ARRAY(Text)),
                "is_holiday": Column(Boolean),
                "is_taiwan_holiday": Column(Boolean),
                "is_approved": Column(Boolean),
                "age_min": Column(Numeric),
                "age_max": Column(Numeric),
                "is_free": Column(Boolean),
                "price_min": Column(Numeric),
                "price_max": Column(Numeric),
                "is_outdoor": Column(Boolean),
                "page_views": Column(Integer, default=0),
                "card_clicks": Column(Integer, default=0),
                "saves": Column(Integer, default=0),
                "registration_clicks": Column(Integer, default=0),
                "like_counts": Column(Integer, default=0),
                "dislike_counts": Column(Integer, default=0),
                "source": Column(Text),
                "lat": Column(Float),
                "lng": Column(Float),
            }
        )
    MODEL_CACHE[table_name] = model
    return model