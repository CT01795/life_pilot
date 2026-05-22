from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy import Float, func, DateTime, Column, String, JSON

Base = declarative_base()
MODEL_CACHE = {}

def create_weather_forecast_model(table_name: str):
    if table_name in MODEL_CACHE:
        return MODEL_CACHE[table_name]
    model = type(
        f"{table_name}_model",  # ✅ class 名稱不要直接用 table_name
        (Base,),
        {
            "__tablename__": table_name,
            "__table_args__": {"extend_existing": True},  
            "country": Column(String),
            "name": Column(String),
            "location": Column(String, primary_key=True),
            "lat": Column(Float),
            "lon": Column(Float),
            "date": Column(DateTime(timezone=True), primary_key=True),
            "weather": Column(JSON),
            "created_at": Column(DateTime(timezone=True), server_default=func.now(), primary_key=True)
        }
    )

    MODEL_CACHE[table_name] = model
    return model