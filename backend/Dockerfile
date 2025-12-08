ARG PYTHON_VERSION=3.12

FROM python:$PYTHON_VERSION-slim AS build

ENV PYTHONUNBUFFERED=1

WORKDIR /app


RUN apt-get update \
    && apt-get install -y --no-install-recommends build-essential curl unzip gcc python3-dev libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# کپی requirements و نصب پکیج‌ها با محدودیت pydantic<2
COPY ./requirements.txt /app/
RUN python3 -m pip install --upgrade pip setuptools \
    && pip install --no-cache-dir "pydantic<2" -r /app/requirements.txt

FROM python:$PYTHON_VERSION-slim

ENV PYTHON_LIB_PATH=/usr/local/lib/python${PYTHON_VERSION%.*}/site-packages
WORKDIR /app

RUN rm -rf $PYTHON_LIB_PATH/*

# انتقال پکیج‌ها و باینری‌ها از stage build
COPY --from=build $PYTHON_LIB_PATH $PYTHON_LIB_PATH
COPY --from=build /usr/local/bin /usr/local/bin

# کپی کل پروژه
COPY . /app

# CMD برای اجرای migrations و start اپلیکیشن
CMD ["bash", "-c", "alembic upgrade head && exec python main.py"]

