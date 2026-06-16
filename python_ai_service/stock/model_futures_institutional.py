from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy import (
    BigInteger,
    String,
    Column,
    TIMESTAMP,
)

Base = declarative_base()
MODEL_CACHE = {}

def create_futures_institutional_model(table_name: str):
    if table_name in MODEL_CACHE:
        return MODEL_CACHE[table_name]
    model = type(
        f"{table_name}_model",  # class 名稱
        (Base,),
        {
            "__tablename__": table_name,
            "__table_args__": {"extend_existing": True},  
            "id": Column(BigInteger, primary_key=True),
            "date": Column(TIMESTAMP(timezone=True)),
            "product_name": Column(String),
            "identity_type": Column(String),
            "trade_long_qty": Column(BigInteger),
            "trade_long_amount": Column(BigInteger),
            "trade_short_qty": Column(BigInteger),
            "trade_short_amount": Column(BigInteger),
            "trade_net_qty": Column(BigInteger),
            "trade_net_amount": Column(BigInteger),
            "oi_long_qty": Column(BigInteger),
            "oi_long_amount": Column(BigInteger),
            "oi_short_qty": Column(BigInteger),
            "oi_short_amount": Column(BigInteger),
            "oi_net_qty": Column(BigInteger),
            "oi_net_amount": Column(BigInteger)
        }
    )
    MODEL_CACHE[table_name] = model
    return model