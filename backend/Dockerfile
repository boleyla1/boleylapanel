ARG PYTHON_VERSION=3.12

FROM python:$PYTHON_VERSION-slim AS build

ENV PYTHONUNBUFFERED=1
WORKDIR /code

# تنظیم DNS قبل از هر کاری
RUN echo "nameserver 8.8.8.8" > /etc/resolv.conf \
    && echo "nameserver 8.8.4.4" >> /etc/resolv.conf

# نصب بسته‌های مورد نیاز
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        build-essential \
        curl \
        unzip \
        gcc \
        python3-dev \
        libpq-dev \
    && rm -rf /var/lib/apt/lists/*

COPY ./requirements.txt /code/
RUN python3 -m pip install --upgrade pip setuptools \
    && pip install --no-cache-dir -r /code/requirements.txt

FROM python:$PYTHON_VERSION-slim

ENV PYTHON_LIB_PATH=/usr/local/lib/python${PYTHON_VERSION%.*}/site-packages
WORKDIR /code

RUN rm -rf $PYTHON_LIB_PATH/*

COPY --from=build $PYTHON_LIB_PATH $PYTHON_LIB_PATH
COPY --from=build /usr/local/bin /usr/local/bin

COPY . /code

EXPOSE 8000
CMD ["bash", "-c", "alembic upgrade head; python main.py"]
