from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy import (
    BigInteger,
    String,
    Column,
    TIMESTAMP,
    Text,
)

Base = declarative_base()
MODEL_CACHE = {}

def create_stock_institutional_model(table_name: str):
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
            "stock_no": Column(String, nullable=False),
            "stock_name": Column(String),
            "foreign_buy": Column(BigInteger),
            "foreign_sell": Column(BigInteger),
            "foreign_diff": Column(BigInteger),
            "foreign_dealer_buy": Column(BigInteger),
            "foreign_dealer_sell": Column(BigInteger),
            "foreign_dealer_diff": Column(BigInteger),
            "trust_buy": Column(BigInteger),
            "trust_sell": Column(BigInteger),
            "trust_diff": Column(BigInteger),
            "dealer_diff": Column(BigInteger),
            "dealer_self_buy": Column(BigInteger),
            "dealer_self_sell": Column(BigInteger),
            "dealer_self_diff": Column(BigInteger),
            "dealer_hedge_buy": Column(BigInteger),
            "dealer_hedge_sell": Column(BigInteger),
            "dealer_hedge_diff": Column(BigInteger),
            "total_diff": Column(BigInteger),
            "source": Column(Text),
        }
    )
    MODEL_CACHE[table_name] = model
    return model