import requests

url = "https://life-pilot.onrender.com/update_model"

response = requests.post(url)  # ⚠️ 一定要 POST
print("Status code:", response.status_code)
print("Response text:", response.text)

try:
    data = response.json()
    print("JSON response:", data)
except Exception as e:
    print("Failed to parse JSON:", e)