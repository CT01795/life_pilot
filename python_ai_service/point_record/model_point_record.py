import uuid

from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy import (
    Boolean,
    DateTime,
    Integer,
    String,
    Column,
    Text,
)
from sqlalchemy.sql import func

Base = declarative_base()
MODEL_CACHE = {}

def create_point_record_model(table_name: str):
    if table_name in MODEL_CACHE:
        return MODEL_CACHE[table_name]
    model = type(
        f"{table_name}_model",  # ✅ class 名稱不要直接用 table_name
        (Base,),
        {
            "__tablename__": table_name,
            "__table_args__": {"extend_existing": True},  
            "id": Column(String, primary_key=True, default=lambda: str(uuid.uuid4())),
            "account": Column(String),
            "master_graph_url": Column(Text),  # Uint8List → binary
            "points": Column(Integer, default=0),
            "created_by": Column(String),
            "created_at": Column(DateTime(timezone=True), server_default=func.now()),
            "is_valid": Column(Boolean),
            "category": Column(String),
        }
    )

    MODEL_CACHE[table_name] = model
    return model