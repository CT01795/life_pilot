import uuid

from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy import Text, func, DateTime, Boolean, Column, String
from sqlalchemy.dialects.postgresql import JSONB

Base = declarative_base()
MODEL_CACHE = {}

def create_business_plan_model(table_name: str):
    if table_name in MODEL_CACHE:
        return MODEL_CACHE[table_name]
    model = type(
        f"{table_name}_model",  # ✅ class 名稱不要直接用 table_name
        (Base,),
        {
            "__tablename__": table_name,
            "__table_args__": {"extend_existing": True},  
            "id": Column(String, primary_key=True, default=lambda: str(uuid.uuid4())),
            "created_by": Column(String),
            "created_at": Column(DateTime(timezone=True), server_default=func.now()),
            "template_id": Column(String),
            "title": Column(Text),  
            "is_valid": Column(Boolean)
        }
    )

    MODEL_CACHE[table_name] = model
    return model