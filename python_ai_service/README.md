# Life Pilot 後端開發

## 需求

- Python 3.11
- 資料庫連線字串 `DB_URL`

Python 3.13 目前無法搭配本專案指定的 `numpy < 2.0` 安裝完整相依套件，請使用 Python 3.11，以符合 CI 環境。

## 建立本機環境（Windows PowerShell）

在 `python_ai_service` 資料夾中執行：

```powershell
py -3.11 -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install -r requirements.txt
```

若電腦沒有 `py` 指令，請在 VS Code 選擇 `.venv\Scripts\python.exe` 作為 Python 解譯器。

## 設定環境變數

請在本機設定 `DB_URL`，不要把實際連線字串提交到 Git：

```powershell
$env:DB_URL = "postgresql://USER:PASSWORD@HOST:5432/DATABASE"
```

## 啟動 API

```powershell
uvicorn app:app --reload
```

啟動後可開啟 `http://127.0.0.1:8000/health` 確認服務狀態。

## 執行測試

```powershell
python -m unittest discover -s tests
```

健康檢查測試會使用記憶體資料庫，不會連線到正式資料庫。
