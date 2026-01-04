FROM ghcr.io/mlflow/mlflow:v2.8.1

# Install psycopg2-binary for PostgreSQL support
# Using binary version to avoid compilation requirements
RUN pip install --no-cache-dir psycopg2-binary>=2.9.0

# Install boto3 for S3/MinIO support (already in base image, but ensure it's available)
RUN pip install --no-cache-dir boto3>=1.28.0

# Keep the default MLflow entrypoint
# The command will be overridden in docker-compose.dev.yml

