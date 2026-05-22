import uuid

from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy import Text, func, DateTime, Boolean, Column, String, Integer, Float

Base = declarative_base()
MODEL_CACHE = {}

def create_accounting_account_model(table_name: str):
    if table_name in MODEL_CACHE:
        return MODEL_CACHE[table_name]
    model = type(
        f"{table_name}_model",  # ✅ class 名稱不要直接用 table_name
        (Base,),
        {
            "__tablename__": table_name,
            "__table_args__": {"extend_existing": True},  
            "id": Column(String, primary_key=True),
            "account": Column(String),
            "master_graph_url": Column(Text),  # Uint8List → binary
            "balance": Column(Integer, default=0),
            "main_currency": Column(String),
            "exchange_rate": Column(Float),
            "category": Column(String),
            "is_valid": Column(Boolean),
            "created_by": Column(String),
            "created_at": Column(DateTime(timezone=True), server_default=func.now())
        }
    )

    MODEL_CACHE[table_name] = model
    return model