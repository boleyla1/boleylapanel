ARG PYTHON_VERSION=3.12

FROM python:$PYTHON_VERSION-slim AS build

ENV PYTHONUNBUFFERED=1
WORKDIR /code

# Use Cloudflare mirror (fastest globally)
RUN rm -f /etc/apt/sources.list.d/* \
    && echo "deb http://deb.debian.org/debian trixie main contrib non-free" > /etc/apt/sources.list \
    && echo "deb http://deb.debian.org/debian trixie-updates main contrib non-free" >> /etc/apt/sources.list \
    && echo "deb http://security.debian.org/debian-security trixie-security main contrib non-free" >> /etc/apt/sources.list

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        build-essential \
        gcc \
        python3-dev \
        default-libmysqlclient-dev \
        pkg-config \
    && rm -rf /var/lib/apt/lists/*

COPY ./requirements.txt /code/
RUN python3 -m pip install --upgrade pip setuptools \
    && pip install --no-cache-dir --upgrade -r /code/requirements.txt

FROM python:$PYTHON_VERSION-slim

ENV PYTHON_LIB_PATH=/usr/local/lib/python3.12/site-packages
WORKDIR /code

RUN rm -f /etc/apt/sources.list.d/* \
    && echo "deb http://deb.debian.org/debian trixie main contrib non-free" > /etc/apt/sources.list \
    && echo "deb http://deb.debian.org/debian trixie-updates main contrib non-free" >> /etc/apt/sources.list

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        default-libmysqlclient-dev \
    && rm -rf /var/lib/apt/lists/*

COPY --from=build $PYTHON_LIB_PATH $PYTHON_LIB_PATH
COPY --from=build /usr/local/bin /usr/local/bin

COPY . /code

EXPOSE 8000
CMD ["bash", "-c", "alembic upgrade head; uvicorn app.main:app --host 0.0.0.0 --port 8000"]
