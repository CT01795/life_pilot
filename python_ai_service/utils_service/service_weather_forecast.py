from datetime import datetime, timedelta

from sqlalchemy.orm import Session
import logging
import sys
from fastapi import APIRouter, Body
from config import SessionLocal

from utils_service.model_weather_forecast import create_weather_forecast_model

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[logging.StreamHandler(sys.stdout)]
)

router = APIRouter()
@router.post(
      "/utils_service/delete_weather_forecast"
      , summary="刪除天氣預報"
      , description="""刪除天氣預報, 參數
        {'table_name': tableName,}""")     
def route_delete_weather_forecast(payload: dict = Body(...)):
    table_name = payload.get("table_name")
    db: Session = SessionLocal()
    try:
      WeatherForecastModel = create_weather_forecast_model(table_name)
      db.query(WeatherForecastModel).filter(
        WeatherForecastModel.date <= (
            datetime.now() - timedelta(days=1)
        )
      ).delete(synchronize_session=False)
      db.commit()
      return {"status": "ok"}
    finally:
      db.close()

@router.post(
      "/utils_service/select_weather_forecast"
      , summary="取得天氣預報"
      , description="""取得天氣預報, 參數
        {'table_name': table_name, 
         'location': location, 
         'date': date, 
         'created_at': created_at}""")
def route_select_weather_forecast(payload: dict = Body(...)):
    table_name = payload.get("table_name")
    location = payload.get("location")
    inputDate = datetime.fromisoformat(payload.get("date"))
    inputCreated_at = datetime.fromisoformat(payload.get("created_at"))
    db: Session = SessionLocal()
    try:
      WeatherForecastModel = create_weather_forecast_model(table_name)
      date = inputDate
      created_at = inputCreated_at
      query = db.query(WeatherForecastModel).filter(WeatherForecastModel.location == location).filter(
        WeatherForecastModel.date >= date).filter(
           WeatherForecastModel.created_at >= created_at).order_by(WeatherForecastModel.date)
      weatherForecastList = query.all()
      if not weatherForecastList:
        return []
      # db.commit()
      return [
            {
                "weather": weather_forecast.weather
            }
            for weather_forecast in weatherForecastList
        ]
    finally:
      db.close()

@router.post(
      "/utils_service/insert_weather_forecast"
      , summary="插入天氣預報"
      , description="""插入新的天氣預報, 參數
        {'table_name': tableName,
         'items': [JSON],}""")   
def route_insert_weather_forecast(payload: dict = Body(...)):
    table_name = payload.get("table_name")
    items = payload.get("items")
    db: Session = SessionLocal()
    try:
      WeatherForecastModel = create_weather_forecast_model(table_name)
      objects = [WeatherForecastModel(**item) for item in items]
      db.bulk_save_objects(objects)
      db.commit()
      return {"status": "ok"}
    finally:
      db.close()