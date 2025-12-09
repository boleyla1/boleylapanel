FROM python:3.12-slim

WORKDIR /app

# استفاده از Mirror سریع برای نصب پکیج‌ها
RUN sed -i 's|deb.debian.org|mirror.arvancloud.ir/debian|g' /etc/apt/sources.list.d/debian.sources 2>/dev/null || \
    echo "deb http://deb.debian.org/debian bookworm main" > /etc/apt/sources.list

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        gcc \
        default-libmysqlclient-dev \
        pkg-config \
        curl \
    && rm -rf /var/lib/apt/lists/*

# نصب وابستگی‌های Python
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# کپی کد برنامه
COPY . .

ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
