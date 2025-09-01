from fastapi import FastAPI
from pydantic import BaseModel

app = FastAPI(title="Summarizer App Placeholder", version="0.1.0")

class Health(BaseModel):
    status: str

@app.get("/", response_model=Health)
def root():
    return {"status": "ok"}

@app.get("/healthz", response_model=Health)
def health():
    return {"status": "healthy"}
