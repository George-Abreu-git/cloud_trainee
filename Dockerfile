FROM python:3.11-slim AS builder

WORKDIR /app

COPY requirements.txt .

RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

FROM python:3.11-slim

LABEL maintainer="georgeabreu68@outlook.com"
LABEL version="1.0.0"
LABEL description="Trainee DevOps API - Flask"

ENV FLASK_ENV=production
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

WORKDIR /app

COPY --from=builder /install /usr/local

COPY app.py .

RUN adduser --disabled-password --no-create-home --gecos "" appuser

RUN chown -R appuser:appuser /app

USER appuser

EXPOSE 5000

HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3  \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:5000/health')" \
    || exit 1

CMD ["python", "-m", "flask", "run", "--host=0.0.0.0", "--port=5000"]