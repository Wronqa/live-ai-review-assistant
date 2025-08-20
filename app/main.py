from fastapi import FastAPI

app = FastAPI(title="LARA")

@app.get("/health")
def health():
    return {"status": "ok"}