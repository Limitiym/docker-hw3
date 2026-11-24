FROM python:3.13-slim

WORKDIR /app

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

COPY app/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app/app.py .

RUN groupadd -g 10001 appuser && \
    useradd -u 10001 -g 10001 appuser && \
    mkdir -p /data && \
    chown appuser:appuser /data

USER appuser

EXPOSE 8000

CMD ["python", "app.py"]
