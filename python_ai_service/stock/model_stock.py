from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy import (
    Float,
    Integer,
    String,
    Column,
    Text,
    TIMESTAMP,
)
from sqlalchemy.sql import func

Base = declarative_base()
MODEL_CACHE = {}

def create_stock_model(table_name: str):
    if table_name in MODEL_CACHE:
        return MODEL_CACHE[table_name]
    if table_name == "stock_daily_price":
        model = type(
            f"{table_name}_model",  # class 名稱
            (Base,),
            {
                "__tablename__": table_name,
                "__table_args__": {"extend_existing": True},  
                "security_code": Column(String, primary_key=True),
                "security_name": Column(String),
                "traded_number": Column(Float),
                "transactions_number": Column(Integer),
                "transaction_amount": Column(Float),
                "opening_price": Column(Float),
                "highest_price": Column(Float),
                "lowest_price": Column(Float),
                "closing_price": Column(Float),
                "change": Column(Text),
                "price_difference": Column(Float),
                "final_reveal_buying_price": Column(Float),
                "final_reveal_buying_volume": Column(Float),
                "final_reveal_selling_price": Column(Float),
                "final_reveal_selling_volume": Column(Float),
                "pe_ratio": Column(Float),
                "date": Column(TIMESTAMP(timezone=True), primary_key=True),
                "created_at": Column(TIMESTAMP(timezone=True), server_default=func.now()),
                "source": Column(Text),
                "ma5": Column(Float),
                "ma20": Column(Float),
                "high20": Column(Float),
                "pct_change": Column(Float),
                "vol5": Column(Float),
                "rsi": Column(Float),
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
                "type": Column(String, primary_key=True),
            }
        )
    MODEL_CACHE[table_name] = model
    return model