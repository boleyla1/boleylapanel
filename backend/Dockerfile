ARG PYTHON_VERSION=3.11

FROM python:$PYTHON_VERSION-slim AS build

ENV PYTHONUNBUFFERED=1

WORKDIR /app

# نصب پیش‌نیازهای build و upgrade pip, setuptools, wheel
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       build-essential \
       curl \
       unzip \
       gcc \
       python3-dev \
       libpq-dev \
       git \
       libyaml-dev \
    && python3 -m pip install --upgrade pip setuptools wheel cython \
    && rm -rf /var/lib/apt/lists/*

# کپی requirements
COPY ./requirements.txt /app/

# نصب requirements (حالا PyYAML راحت build میشه)
RUN pip install --no-cache-dir -r /app/requirements.txt

# -------------------------
# Stage دوم: image سبک
FROM python:$PYTHON_VERSION-slim

WORKDIR /app

# کپی پکیج‌ها و باینری‌ها
COPY --from=build /usr/local/lib/python3.11/site-packages /usr/local/lib/python3.11/site-packages
COPY --from=build /usr/local/bin /usr/local/bin

# کپی پروژه
COPY . /app

CMD ["bash", "-c", "alembic upgrade head; python main.py"]
