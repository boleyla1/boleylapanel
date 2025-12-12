# استفاده از Python 3.12
FROM python:3.12-slim

# تنظیم working directory
WORKDIR /app

# کپی requirements
COPY requirements.txt .

# نصب dependencies
RUN pip install --no-cache-dir -r requirements.txt

# کپی کل پوشه backend
COPY . .

# Expose port
EXPOSE 8000

# دستور اجرا - توجه کن به مسیر app.main
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
