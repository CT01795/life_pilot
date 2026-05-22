from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy import (
    BigInteger,
    String,
    Column,
    Text,
    Boolean,
    TIMESTAMP,
)
from sqlalchemy.dialects.postgresql import ARRAY
from sqlalchemy.sql import func

Base = declarative_base()
MODEL_CACHE = {}

def create_feedback_model(table_name: str):
    if table_name in MODEL_CACHE:
        return MODEL_CACHE[table_name]
    model = type(
        f"{table_name}_model",  # class 名稱
        (Base,),
        {
            "__tablename__": table_name,
            "__table_args__": {"extend_existing": True},  
            "id": Column(
                BigInteger,
                primary_key=True,
                autoincrement=True
            ),
            "subject": Column(String),
            "content": Column(Text),
            # PostgreSQL text[]
            "cc": Column(ARRAY(Text)),
            # PostgreSQL text[]
            "screenshot": Column(ARRAY(Text)),
            "created_by": Column(String),
            "created_at": Column(
                TIMESTAMP(timezone=True),
                server_default=func.now()
            ),
            "is_ok": Column(Boolean, default=False),
            "deal_by": Column(Text),
            "deal_at": Column(TIMESTAMP(timezone=True)),
        }
    )
    MODEL_CACHE[table_name] = model
    return model