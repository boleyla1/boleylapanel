FROM python:3.12-slim

WORKDIR /app

# Use fast Debian mirror
RUN sed -i 's|deb.debian.org|ftp.de.debian.org|g' /etc/apt/sources.list.d/debian.sources && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        curl \
        default-libmysqlclient-dev \
        build-essential \
        pkg-config \
        ca-certificates && \
    rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--reload"]
