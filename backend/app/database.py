"""
Database connection setup.

This backend connects to Postgres two different ways, chosen by config:

  - Locally and in tests: a normal SQLAlchemy connection over TCP (psycopg to a
    local Postgres, or SQLite for the test suite). This is the default.

  - In AWS (use_data_api=True): the RDS Data API — SQL sent to Aurora over
    HTTPS, so the Lambda never enters the VPC and we avoid a NAT Gateway. Same
    SQLAlchemy models and queries; only the engine's connection differs.

Aurora Serverless pauses to zero ACUs when idle and takes ~15s to resume. For
the TCP path, pool_pre_ping + a connect timeout survive that pause/resume. The
Data API is stateless HTTP, so it sidesteps the stale-connection problem
entirely — there's no long-lived socket to go bad.
"""
from sqlalchemy import create_engine
from sqlalchemy.orm import declarative_base, sessionmaker

from app.config import settings

if settings.use_data_api:
    # SQL-over-HTTPS to Aurora. The URL carries only the database name; the
    # cluster and secret ARNs (from Terraform outputs) go in connect_args.
    engine = create_engine(
        f"postgresql+auroradataapi://:@/{settings.aurora_database_name}",
        connect_args={
            "aurora_cluster_arn": settings.aurora_cluster_arn,
            "secret_arn": settings.aurora_secret_arn,
        },
    )
else:
    # Normal TCP connection (local Postgres, or SQLite in tests). The
    # connect_timeout arg is Postgres-only; SQLite rejects it.
    _connect_args = {}
    if settings.database_url.startswith("postgresql"):
        _connect_args["connect_timeout"] = 20

    engine = create_engine(
        settings.database_url,
        pool_pre_ping=True,          # survive Aurora pause/resume cycles
        pool_recycle=280,            # recycle connections before idle timeouts
        connect_args=_connect_args,  # wait out the ~15s cold start (Postgres only)
    )

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

# Whether tables have been ensured for this (warm) Lambda container / process.
_initialized = False


def init_db(retries: int = 12, delay: float = 3.0) -> None:
    """
    Create tables, tolerating Aurora Serverless auto-pause.

    When Aurora is paused, the Data API's first call raises
    DatabaseResumingException while the cluster wakes (~15-25s). We retry until
    it's up. This runs on the first DB request (not at import), so it has the
    full function-timeout budget rather than the 10s Lambda INIT window.
    """
    import time

    from app import models  # noqa: F401 — ensure tables are registered on Base

    last_error = None
    for _ in range(retries):
        try:
            Base.metadata.create_all(bind=engine)
            return
        except Exception as e:  # retry only while Aurora is resuming
            if "resuming" in str(e).lower():
                last_error = e
                time.sleep(delay)
                continue
            raise
    raise last_error


def get_db():
    """FastAPI dependency that yields a database session per request."""
    global _initialized
    if not _initialized:
        init_db()
        _initialized = True

    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
