# Use Python 3.11 slim for better package compatibility
ARG PYTHON_VERSION=3.11

FROM python:$PYTHON_VERSION-slim AS build

ENV PYTHONUNBUFFERED=1

WORKDIR /app

# نصب پیش‌نیازها برای pip و build کردن پکیج‌ها
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       build-essential \
       curl \
       unzip \
       gcc \
       python3-dev \
       libpq-dev \
       git \
    && rm -rf /var/lib/apt/lists/*

# ارتقا pip, setuptools و wheel + نصب Cython برای PyYAML
RUN python3 -m pip install --upgrade pip setuptools wheel cython

# کپی requirements و نصب پکیج‌ها
COPY ./requirements.txt /app/
RUN pip install --no-cache-dir -r /app/requirements.txt

# --------------------------------------
# Stage دوم: image نهایی سبک و تمیز
FROM python:$PYTHON_VERSION-slim

WORKDIR /app

# کپی پکیج‌ها و باینری‌ها از stage build
COPY --from=build /usr/local/lib/python3.11/site-packages /usr/local/lib/python3.11/site-packages
COPY --from=build /usr/local/bin /usr/local/bin

# کپی کل پروژه
COPY . /app

# اجرای migrations و استارت اپلیکیشن
CMD ["bash", "-c", "alembic upgrade head; python main.py"]
