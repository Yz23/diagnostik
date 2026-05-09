FROM python:3.11-slim

WORKDIR /app
COPY libs/diagnostik_common /app/libs/diagnostik_common
COPY apps/worker /app/apps/worker
RUN pip install --no-cache-dir -e /app/libs/diagnostik_common -e /app/apps/worker
CMD ["python", "/app/apps/worker/src/main.py"]
