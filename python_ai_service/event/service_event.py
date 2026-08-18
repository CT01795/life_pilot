import base64
import logging
import sys
from urllib.parse import urlsplit

from fastapi import APIRouter, Body, Depends, HTTPException
import requests
from fastapi.responses import JSONResponse

from security.supabase_auth import require_supabase_admin

# Only proxy the exact public endpoints used by the application.
ALLOWED_REQUEST_PATHS = {
    ("GET", "www.twse.com.tw"): {
        "/exchangeReport/MI_INDEX",
        "/rwd/zh/fund/T86",
    },
    ("GET", "www.tpex.org.tw"): {
        "/www/zh-tw/afterTrading/otc",
    },
    ("POST", "www.tpex.org.tw"): {
        "/www/zh-tw/insti/dailyTrade",
    },
    ("GET", "www.taifex.com.tw"): {
        "/cht/3/futContractsDateDown",
    },
    ("GET", "www.taiwan.net.tw"): {
        "/m1.aspx",
    },
}

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[logging.StreamHandler(sys.stdout)]
)
logger = logging.getLogger(__name__)

router = APIRouter(dependencies=[Depends(require_supabase_admin)])


def _validate_request_target(url: object, method: object) -> tuple[str, str]:
    if not isinstance(url, str) or not url.strip():
        raise HTTPException(status_code=400, detail="A valid URL is required")
    if not isinstance(method, str):
        raise HTTPException(status_code=400, detail="A valid method is required")

    normalized_method = method.upper()
    if normalized_method not in {"GET", "POST"}:
        raise HTTPException(status_code=400, detail="Only GET and POST are allowed")

    try:
        parsed_url = urlsplit(url)
        port = parsed_url.port
    except ValueError as error:
        raise HTTPException(status_code=400, detail="Invalid URL") from error

    hostname = parsed_url.hostname
    if (
        parsed_url.scheme.lower() != "https"
        or hostname is None
        or parsed_url.username is not None
        or parsed_url.password is not None
        or port not in {None, 443}
    ):
        raise HTTPException(status_code=400, detail="Only valid HTTPS URLs are allowed")

    allowed_paths = ALLOWED_REQUEST_PATHS.get(
        (normalized_method, hostname.lower()),
    )
    if allowed_paths is None or parsed_url.path not in allowed_paths:
        raise HTTPException(status_code=403, detail="Request target is not allowed")

    return url, normalized_method


@router.post(
      "/event/get_url_data"
      , summary="代理取得URL資料"
      , description="""代理取得URL資料, 參數
        { 'url': url
        , 'method': method
        , 'data_type': data_type}""")
def get_url_data(payload: dict = Body(...)):
    url, method = _validate_request_target(
        payload.get("url"),
        payload.get("method", "GET"),
    )

    try:
        data_type = payload.get("data_type")
        form_data = payload.get("body", {})
        headers = {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0 Safari/537.36",
            "Referer": url}
        if method.upper() == "POST":
            res = requests.post(
                url,data=form_data,timeout=(10, 60),headers=headers,
                allow_redirects=False,
            )
        else:
            res = requests.get(
                url,timeout=(10, 180),headers=headers,
                allow_redirects=False,
            )
        res.raise_for_status()
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
    except Exception:
        logger.exception("External event request failed")
        return {
            "status": "error",
            "message": "External service request failed",
        }
