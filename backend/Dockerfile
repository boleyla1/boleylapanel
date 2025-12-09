# ===== Base image =====
FROM python:3.12-slim

# ===== Set working directory =====
WORKDIR /code

# ===== Update sources and install dependencies =====
RUN rm -f /etc/apt/sources.list.d/* \
 && echo "deb http://deb.debian.org/debian bookworm main contrib non-free" > /etc/apt/sources.list \
 && apt-get update -qq \
 && apt-get install -y --no-install-recommends \
        build-essential \
        gcc \
        python3-dev \
        default-libmysqlclient-dev \
        curl \
 && rm -rf /var/lib/apt/lists/*

# ===== Copy requirements =====
COPY ./requirements.txt /code/

# ===== Install Python dependencies =====
RUN python3 -m pip install --upgrade pip setuptools \
 && pip install --no-cache-dir -r /code/requirements.txt

# ===== Copy application code =====
COPY . /code

# ===== Expose port =====
EXPOSE 8000

# ===== Command =====
CMD ["python3", "main.py"]
