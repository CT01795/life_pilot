import base64
from datetime import datetime

from sqlalchemy.orm import Session
import logging
import sys
from sqlalchemy import text
from fastapi import APIRouter, Body
import requests
from fastapi.responses import JSONResponse
from config import engine, SessionLocal
from event.model_event import create_event_model
import json
import urllib3

from utils_service.utils import model_to_dict

# 關掉 SSL warning
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[logging.StreamHandler(sys.stdout)]
)

router = APIRouter()
@router.post(
      "/event/get_api_key"
      , summary="取得API key"
      , description="""取得API key, 參數
        {'p_key_name': p_key_name}""")
def route_get_api_key(payload: dict = Body(...)):
    p_key_name = payload.get("p_key_name")
    with engine.begin() as conn:
        result = conn.execute(
            text("SELECT get_key(:p_key_name)"),
            {"p_key_name": p_key_name}
        )
        value = result.scalar()

    return {"value": value}

@router.post(
    "/event/cleanup_recommended_events"
    , summary="刪除舊的推薦活動"
    , description="""刪除舊的推薦活動, 參數
        {'cutoff': cutoff}"""
)   
def route_cleanup_recommended_events(payload: dict = Body(...)):
    cutoff = payload.get("cutoff")
    with engine.begin() as conn:
        conn.execute(
            text("SELECT cleanup_recommended_events(:cutoff)"),
            {"cutoff": cutoff}
        )
    return {"status": "ok"}

@router.post(
    "/event/get_filtered" 
    , summary="取得過濾後的活動"
    , description="""取得過濾後的活動, 參數
        { 'table_name': tableName
        , 'inputid': id
        , 'inputdates': inputDateS
        , 'inputdatee': inputDateE
        , 'inputuser': inputUser,}""")   
def route_get_filtered(payload: dict = Body(...)):
    table_name = payload.get("table_name")
    query = f"SELECT row_to_json(t)  FROM get_filtered_{table_name}(:payload) t"
    with engine.begin() as conn:
        result = conn.execute(
            text(query),
            {"payload": json.dumps(payload)}
        )
        rows = [r[0] for r in result.fetchall()]
        return rows

@router.post(
      "/event/insert"
      , summary="插入事件"
      , description="""插入新的活動, 參數
        { 'table_name': table_name
        , 'events': events,}""")   
def route_insert(payload: dict = Body(...)):
    table_name = payload.get("table_name")
    events_data = payload.get("events") # 支持批量插入
    db: Session = SessionLocal()
    try:
      EventModel = create_event_model(table_name)
      objects = [
            EventModel(**event_data)
            for event_data in events_data
        ]

      db.add_all(objects) 
      db.commit()
      return {"status": "ok"}
    finally:
      db.close()

@router.post(
      "/event/update"
      , summary="更新事件"
      , description="""更新事件內容, 參數
        { 'table_name': table_name
        , 'current_account': current_account
        , 'event': event,}""")     
def route_update(payload: dict = Body(...)):
    table_name = payload.get("table_name")
    current_account = payload.get("current_account")
    event_data = payload.get("event")
    db: Session = SessionLocal()
    try:
      EventModel = create_event_model(table_name)
      query = db.query(EventModel).filter(EventModel.id == event_data["id"])
      # 如果不是系統管理員，限制只能更新自己的事件
      if current_account != "minavi@alumni.nccu.edu.tw" and event_data.get("account"):
          query = query.filter(EventModel.account == event_data["account"])
      event = query.first()
      if not event:
          raise Exception("event not found")
      # 更新所有傳入欄位
      for k, v in event_data.items():
          setattr(event, k, v)
      db.commit()
      return {"status": "ok"}
    finally:
      db.close()

@router.post(
      "/event/delete"
      , summary="刪除事件"
      , description="""刪除事件, 參數
        { 'table_name': table_name
        , 'current_account': current_account
        , 'event': event,}""")     
def route_delete(payload: dict = Body(...)):
    table_name = payload.get("table_name")
    current_account = payload.get("current_account")
    event_data = payload.get("event")
    db: Session = SessionLocal()
    try:
      EventModel = create_event_model(table_name)
      query = db.query(EventModel).filter(EventModel.id == event_data["id"])
      # 如果不是系統管理員，限制只能刪自己的事件
      if current_account != "minavi@alumni.nccu.edu.tw":
        query = query.filter(EventModel.account == current_account)
      event = query.first()
      if not event:
        raise Exception("event not found")
      db.delete(event)
      db.commit()
      return {"status": "ok"}
    finally:
      db.close()

@router.post(
      "/event/increment_event_counter"
      , summary="增加事件計數"
      , description="""增加事件計數, 參數
        { 'p_event_id': p_event_id
        , 'p_event_name': p_event_name
        , 'p_column': p_column
        , 'p_account': p_account,}""")     
def route_increment_event_counter(payload: dict = Body(...)):
    p_event_id = payload.get("p_event_id")
    p_event_name = payload.get("p_event_name")
    p_column = payload.get("p_column")
    p_account = payload.get("p_account")
    with engine.begin() as conn:
        conn.execute(
            text("SELECT increment_event_counter(:p_event_id, :p_event_name, :p_column, :p_account)"),
            {
                "p_event_id": p_event_id,
                "p_event_name": p_event_name,
                "p_column": p_column,
                "p_account": p_account
            }
        )
    return {"status": "ok"}

@router.post(
      "/event/search_lat_lng"
      , summary="搜尋經緯度"
      , description="""搜尋經緯度, 參數
        { 'city_like': city_like
        , 'location_like': location_like
        , 'country_like': country_like,}""")     
def route_search_lat_lng(payload: dict = Body(...)):
    city_like = payload.get("city_like")
    location_like = payload.get("location_like")
    country_like = payload.get("country_like")
    with engine.begin() as conn:
        res = conn.execute(
            text("""
                SELECT * FROM search_lat_lng(:city_like,:location_like,:country_like)
            """),
            {
                "city_like": city_like,
                "location_like": location_like,
                "country_like": country_like
            }
        )
        result = res.fetchone()

        return dict(result._mapping) if result else None
    
@router.post(
      "/event/select_event_url"
      , summary="選擇事件URL"
      , description="""選擇事件URL, 參數
        { 'table_name': table_name
        , 'master_url': master_url
        , 'start_date': start_date,}""")     
def route_select_event_url(payload: dict = Body(...)):
    table_name = payload.get("table_name")
    master_url = payload.get("master_url")
    start_date = datetime.fromisoformat(payload.get("start_date"))
    db: Session = SessionLocal()
    try:
      EventUrlModel = create_event_model(table_name)
      query = db.query(EventUrlModel).filter(EventUrlModel.master_url == master_url).filter(EventUrlModel.start_date == start_date)
      eventUrl = query.first()
      return {"status": "ok", "is_exists": True} if eventUrl else {"status": "not found", "is_exists": False}
    finally:
      db.close()

@router.post(
      "/event/insert_event_url"
      , summary="新增事件URL"
      , description="""新增事件URL, 參數
        { 'table_name': table_name
        , 'event_url': event_url}""")     
def route_insert_event_url(payload: dict = Body(...)):
    table_name = payload.get("table_name")
    event_url_data = payload.get("event_url")
    db: Session = SessionLocal()
    try:
      EventUrlModel = create_event_model(table_name)
      eventUrl = EventUrlModel(**event_url_data)
      db.add(eventUrl)
      db.commit()
      return {"status": "ok"}
    finally:
      db.close()
   
@router.post(
      "/event/select_events_deleted"
      , summary="查詢已刪除事件"
      , description="""查詢已刪除事件, 參數
        {'table_name': table_name,}""")     
def route_select_events_deleted(payload: dict = Body(...)):
    table_name = payload.get("table_name")
    db: Session = SessionLocal()
    try:
      EventDeletedModel = create_event_model(table_name)
      query = db.query(EventDeletedModel)
      eventDeletedList = query.all()
      if not eventDeletedList:
        return []
      return [model_to_dict(eventDeleted) for eventDeleted in eventDeletedList]
    finally:
      db.close()


@router.post(
      "/event/get_url_data"
      , summary="代理取得URL資料"
      , description="""代理取得URL資料, 參數
        { 'url': url
        , 'method': method
        , 'data_type': data_type}""")
def get_url_data(payload: dict = Body(...)):
    try:
        data_type = payload.get("data_type")
        url = payload.get("url")
        method = payload.get("method", "GET")
        form_data = payload.get("body", {})
        headers = {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0 Safari/537.36",
            "Referer": url}
        if method.upper() == "POST":
            res = requests.post(
                url,data=form_data,timeout=(10, 60),headers=headers,
                verify=False,
            )
        else:
            res = requests.get(
                url,timeout=(10, 180),headers=headers,
                verify=False,
            )

        # 🔥 自動處理 big5 / utf8
        res.encoding = res.encoding or "utf-8"

        # 🔥 audio / text 分流
        result_data = (
            base64.b64encode(res.content).decode()
            if data_type == "audio"
            else res.text
        )

        return JSONResponse(content={
            "status": "ok",
            "data": result_data
        })
    except Exception as e:
        return {
            "status": "error",
            "message": str(e),
        }