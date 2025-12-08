# =========================================
# Stage 1: Build Dependencies
# =========================================
FROM python:3.12-slim AS build

ENV PYTHONUNBUFFERED=1
WORKDIR /app

# Install curl (needed for DNS/mirror tests)
#RUN apt-get update \
#    && apt-get install -y --no-install-recommends curl \
#    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .

# Install Pydantic <2 to fix Config/model_config error
RUN pip install --no-cache-dir --upgrade pip setuptools \
    && pip install --no-cache-dir "pydantic<2" -r requirements.txt --index-url https://pypi.org/simple --trusted-host pypi.org

# =========================================
# Stage 2: Runtime Image
# =========================================
FROM python:3.12-slim

ENV PYTHONUNBUFFERED=1
ENV PYTHON_LIB_PATH=/usr/local/lib/python3.12/site-packages

WORKDIR /app
RUN rm -rf $PYTHON_LIB_PATH/*

COPY --from=build $PYTHON_LIB_PATH $PYTHON_LIB_PATH
COPY --from=build /usr/local/bin /usr/local/bin

COPY . /app

HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
  CMD curl -f http://localhost:8000/health || exit 1

CMD ["sh", "-c", "alembic upgrade head && python scripts/init_db.py && uvicorn app.main:app --host 0.0.0.0 --port 8000 --workers 1"]
