ARG PYTHON_VERSION=3.12

FROM python:$PYTHON_VERSION-slim AS build

ENV PYTHONUNBUFFERED=1
WORKDIR /code

# نصب پکیج‌های مورد نیاز برای build
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        build-essential \
        gcc \
        python3-dev \
        default-libmysqlclient-dev \
        pkg-config \
    && rm -rf /var/lib/apt/lists/*

# کپی کردن requirements و نصب پکیج‌ها
COPY ./requirements.txt /code/
RUN python3 -m pip install --upgrade pip setuptools \
    && pip install --no-cache-dir -r /code/requirements.txt

# نسخه نهایی
FROM python:$PYTHON_VERSION-slim

ENV PYTHON_LIB_PATH=/usr/local/lib/python3.12/site-packages
WORKDIR /code

# نصب library لازم برای MySQL runtime
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        default-libmysqlclient-dev \
    && rm -rf /var/lib/apt/lists/*

# کپی کردن پکیج‌های build شده
COPY --from=build $PYTHON_LIB_PATH $PYTHON_LIB_PATH
COPY --from=build /usr/local/bin /usr/local/bin

# کپی کردن سورس برنامه
COPY . /code

EXPOSE 8000

# اجرای migration و سرور
CMD ["bash", "-c", "alembic upgrade head; uvicorn app.main:app --host 0.0.0.0 --port 8000"]
