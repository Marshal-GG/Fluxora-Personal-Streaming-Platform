from fastapi import FastAPI, Depends
from fastapi.security import HTTPBearer
from fastapi.testclient import TestClient

app = FastAPI()
bearer = HTTPBearer()

@app.get("/")
def read_root(creds=Depends(bearer)):
    return {"message": "Hello World"}

client = TestClient(app)
response = client.get("/")
print(f"Status: {response.status_code}")
print(f"Detail: {response.json()}")
