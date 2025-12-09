FROM python:3.12-slim

WORKDIR /app

# استفاده از Mirror ایران برای سرعت بالا
RUN echo "deb https://mirror.arvancloud.ir/debian trixie main" > /etc/apt/sources.list && \
    echo "deb https://mirror.arvancloud.ir/debian trixie-updates main" >> /etc/apt/sources.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        curl \
        unzip \
        ca-certificates && \
    rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--reload"]
