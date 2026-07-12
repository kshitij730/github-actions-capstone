from fastapi import FastAPI
from datetime import datetime

app = FastAPI(title="Capstone Health API")

@app.get("/health")
def health():
    return {
        "status": "ok",
        "service": "github-actions-capstone",
        "time": datetime.utcnow().isoformat()
    }