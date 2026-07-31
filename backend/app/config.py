"""
Application configuration.

Values come from environment variables. In AWS, the database URL and JWT
secret are injected from Secrets Manager at deploy time (see Terraform).
Locally, they come from a .env file.
"""
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    # Database (local dev / tests): a normal SQLAlchemy URL (Postgres or SQLite)
    database_url: str = "postgresql+psycopg://postgres:postgres@localhost:5432/miniloom"

    # Database (AWS): when use_data_api is true, we ignore database_url and talk
    # to Aurora over the RDS Data API using these ARNs instead of a TCP
    # connection. Terraform outputs supply these values to the Lambda.
    use_data_api: bool = False
    aurora_cluster_arn: str = ""
    aurora_secret_arn: str = ""
    aurora_database_name: str = "miniloom"

    # Auth (Cognito). We verify JWTs that Cognito issues, using Cognito's
    # PUBLIC keys — so there's no secret to store here. These identify which
    # user pool/app client to trust (from the Terraform outputs).
    cognito_user_pool_id: str = ""
    cognito_client_id: str = ""

    # CORS: comma-separated list of allowed origins. Defaults to "*" for local
    # dev; in AWS it's set to the CloudFront URL (+ localhost) via the Lambda env.
    cors_allow_origins: str = "*"

    # AWS / S3
    aws_region: str = "us-east-1"
    video_bucket: str = "mini-loom-videos-dev"
    presigned_url_expire_seconds: int = 3600  # 1 hour to complete an upload
    max_upload_bytes: int = 200 * 1024 * 1024  # 200 MB cap, enforced by S3


settings = Settings()
