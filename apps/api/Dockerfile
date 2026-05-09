FROM python:3.11-slim

WORKDIR /app
COPY libs/diagnostik_common /app/libs/diagnostik_common
COPY connectors /app/connectors
COPY pipelines /app/pipelines
COPY apps/api /app/apps/api
RUN pip install --no-cache-dir -e /app/libs/diagnostik_common -e /app/apps/api
ENV PYTHONPATH=/app
EXPOSE 8000
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--app-dir", "/app/apps/api"]
