import uuid

from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy import (
    Float,
    Integer,
    String,
    Column,
    Boolean,
    TIMESTAMP,
)
from sqlalchemy.sql import func

Base = declarative_base()
MODEL_CACHE = {}

def create_game_user_model(table_name: str):
    if table_name in MODEL_CACHE:
        return MODEL_CACHE[table_name]
    model = type(
        f"{table_name}_model",  # class 名稱
        (Base,),
        {
            "__tablename__": table_name,
            "__table_args__": {"extend_existing": True},  
            "id": Column(String, primary_key=True, default=lambda: str(uuid.uuid4())),
            "game_id": Column(String),
            "score": Column(Float),
            "name": Column(String),
            "created_at": Column(
                TIMESTAMP(timezone=True),
                server_default=func.now()
            ),
            "is_pass": Column(Boolean),
        }
    )
    MODEL_CACHE[table_name] = model
    return model

def create_game_list_model(table_name: str):
    if table_name in MODEL_CACHE:
        return MODEL_CACHE[table_name]
    model = type(
        f"{table_name}_model",  # class 名稱
        (Base,),
        {
            "__tablename__": table_name,
            "__table_args__": {"extend_existing": True},  
            "id": Column(String, primary_key=True, default=lambda: str(uuid.uuid4())),
            "game_type": Column(String),
            "game_name": Column(String),
            "level": Column(Integer),
            "created_at": Column(
                TIMESTAMP(timezone=True),
                server_default=func.now()
            ),
        }
    )
    MODEL_CACHE[table_name] = model
    return model

def create_game_translation_synonyms_model(table_name: str):
    if table_name in MODEL_CACHE:
        return MODEL_CACHE[table_name]
    model = type(
        f"{table_name}_model",  # class 名稱
        (Base,),
        {
            "__tablename__": table_name,
            "__table_args__": {"extend_existing": True},  
            "id": Column(String, primary_key=True, default=lambda: str(uuid.uuid4())),
            "question": Column(String),
            "answer": Column(String),
            "created_at": Column(
                TIMESTAMP(timezone=True),
                server_default=func.now()
            ),
            "group": Column(String),
            "rand_key": Column(Float),
            "level": Column(Integer),
        }
    )
    MODEL_CACHE[table_name] = model
    return model

def create_game_grammar_user_model(table_name: str):
    if table_name in MODEL_CACHE:
        return MODEL_CACHE[table_name]
    model = type(
        f"{table_name}_model",  # class 名稱
        (Base,),
        {
            "__tablename__": table_name,
            "__table_args__": {"extend_existing": True},  
            "id": Column(String, primary_key=True, default=lambda: str(uuid.uuid4())),
            "user": Column(String),
            "question_id": Column(String),
            "is_right": Column(Boolean),
            "created_at": Column(
                TIMESTAMP(timezone=True),
                server_default=func.now()
            ),
            "answer": Column(String),
        }
    )
    MODEL_CACHE[table_name] = model
    return model