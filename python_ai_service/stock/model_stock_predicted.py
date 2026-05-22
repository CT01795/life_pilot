import uuid

from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy import (
    JSON,
    Column,
    Float,
    String,
    Column,
    Text,
    TIMESTAMP,
)
from sqlalchemy.sql import func

Base = declarative_base()
MODEL_CACHE = {}

def create_stock_predicted_model(table_name: str):
    if table_name in MODEL_CACHE:
        return MODEL_CACHE[table_name]
    if table_name == "stock_predicted_list":
        model = type(
            f"{table_name}_model",  # class 名稱
            (Base,),
            {
                "__tablename__": table_name,
                "__table_args__": {"extend_existing": True},  
                "id": Column(String, primary_key=True, default=lambda: str(uuid.uuid4())),
                "date": Column(TIMESTAMP(timezone=True)),
                "security_code": Column(String),
                "security_name": Column(String),
                "closing_price": Column(Float),
                "traded_number": Column(Float),
                "pe_ratio": Column(Float),
                "ma5": Column(Float),
                "ma20": Column(Float),
                "high20": Column(Float),
                "vol5": Column(Float),
                "rsi": Column(Float),
                "pct_change": Column(Float),
                "pred_pct": Column(Float),
                "singal": Column(String),
                "singal_text": Column(String),
                "created_at": Column(TIMESTAMP(timezone=True), server_default=func.now()),
            }
        )
    else:
        model = type(
            f"{table_name}_model",  # class 名稱
            (Base,),
            {
                "__tablename__": table_name,
                "__table_args__": {"extend_existing": True},  
                "date": Column(TIMESTAMP(timezone=True), primary_key=True),
                "data": Column(JSON),
                "created_at": Column(TIMESTAMP(timezone=True)),
            }
        )
    MODEL_CACHE[table_name] = model
    return model