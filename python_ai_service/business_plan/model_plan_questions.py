import uuid

from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy import INT, Column, String

Base = declarative_base()
MODEL_CACHE = {}

def create_plan_questions_model(table_name: str):
    if table_name in MODEL_CACHE:
        return MODEL_CACHE[table_name]
    model = type(
        f"{table_name}_model",  # ✅ class 名稱不要直接用 table_name
        (Base,),
        {
            "__tablename__": table_name,
            "__table_args__": {"extend_existing": True},  
            "id": Column(String, primary_key=True),
            "section_id": Column(String), 
            "prompt": Column(String), 
            "sort_order": Column(INT)
        }
    )

    MODEL_CACHE[table_name] = model
    return model