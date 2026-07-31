"""
FastAPI application entry point.

Locally: run with `uvicorn app.main:app --reload`.
In AWS: the `handler` at the bottom lets this same app run inside Lambda
via Mangum, with no code changes between local and production.
"""
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from mangum import Mangum

from app.config import settings
from app.routers import auth, videos

# NOTE: tables are NOT created here. In Lambda, module import runs during the
# 10-second INIT phase — too short for Aurora to resume from auto-pause. Table
# creation happens lazily on the first DB request instead (see database.init_db,
# called from get_db), which has the full function-timeout budget and retries
# through Aurora's resume. Later this moves to Alembic migrations in CI/CD.

app = FastAPI(title="Mini Loom API")

# Allowed origins come from config: "*" locally, the CloudFront URL (+ localhost)
# in AWS. Split the comma-separated env value into a list.
_origins = [o.strip() for o in settings.cors_allow_origins.split(",") if o.strip()]

app.add_middleware(
    CORSMiddleware,
    allow_origins=_origins,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router)
app.include_router(videos.router)


@app.get("/health")
def health():
    return {"status": "ok"}


# Lambda entry point — Mangum adapts FastAPI's ASGI interface to Lambda events
handler = Mangum(app)
