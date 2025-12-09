# ===========================
# Stage 1: Build Dependencies
# ===========================
ARG PYTHON_VERSION=3.11
FROM python:${PYTHON_VERSION}-slim AS build

ENV PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

WORKDIR /build

# نصب ابزارهای build ضروری (برای cryptography و PyYAML)
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       gcc \
       libc-dev \
       libffi-dev \
       curl \
    && rm -rf /var/lib/apt/lists/*

# آپدیت pip و نصب wheel/cython
RUN python3 -m pip install --upgrade pip setuptools wheel cython

# کپی و نصب requirements
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# ===========================
# Stage 2: Runtime Image
# ===========================
FROM python:${PYTHON_VERSION}-slim

ENV PYTHONUNBUFFERED=1

WORKDIR /app

# کپی پکیج‌ها از build stage
COPY --from=build /usr/local/lib/python3.11/site-packages /usr/local/lib/python3.11/site-packages
COPY --from=build /usr/local/bin /usr/local/bin

# کپی کد پروژه
COPY . /app

# پورت پیشفرض FastAPI
EXPOSE 8000

# Healthcheck
HEALTHCHECK --interval=30s --timeout=10s --retries=3 --start-period=40s \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')" || exit 1

# CMD پیشفرض: alembic + init_db + uvicorn
CMD ["sh", "-c", "alembic upgrade head && python scripts/init_db.py && uvicorn app.main:app --host 0.0.0.0 --port 8000"]
