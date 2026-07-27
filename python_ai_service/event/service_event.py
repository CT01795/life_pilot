import base64
import logging
import sys
from fastapi import APIRouter, Body
import requests
from fastapi.responses import JSONResponse
import urllib3

# 關掉 SSL warning
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[logging.StreamHandler(sys.stdout)]
)

router = APIRouter()
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