import uuid

from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy import func, DateTime, Boolean, Column, String

Base = declarative_base()
MODEL_CACHE = {}

def create_user_module_model(table_name: str):
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
            "module_key": Column(String),
            "enabled": Column(Boolean),
            "created_at": Column(DateTime(timezone=True), server_default=func.now()),
            "stop_at": Column(DateTime(timezone=True))
        }
    )

    MODEL_CACHE[table_name] = model
    return model