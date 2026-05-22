from fastapi import Body
from sqlalchemy import text
from sqlalchemy.orm import Session

from config import engine, SessionLocal

def model_to_dict(obj):
    return {
        c.name: getattr(obj, c.name)
        for c in obj.__table__.columns
    }

def route_fetch_data_by_rpc(sql: str, payload: dict):
    params = {
      k: v
      for k, v in payload.items()
    }
    with engine.begin() as conn:
      result = conn.execute(
          text(sql),
          params
      )
      rows = [r[0] for r in result.fetchall()]
    return rows

def route_insert(payload: dict = Body(...)):
    model = payload.get("model")
    data = payload.get("data")
    db: Session = SessionLocal()
    try:
      model_data = model(**data)
      db.add(model_data)
      db.commit()
      return {"status": "ok"}
    finally:
      db.close()