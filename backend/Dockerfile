ARG PYTHON_VERSION=3.12

FROM python:$PYTHON_VERSION-slim

ENV PYTHONUNBUFFERED=1
WORKDIR /code
ENV PYTHON_LIB_PATH=/usr/local/lib/python${PYTHON_VERSION%.*}/site-packages

# نصب وابستگی‌های Python از requirements.txt
COPY ./requirements.txt /code/
RUN python3 -m pip install --upgrade pip setuptools \
    && pip install --no-cache-dir -r /code/requirements.txt

# کپی کردن کد پروژه
COPY . /code

EXPOSE 8000

# اجرای migration و استارت اپ
CMD ["bash", "-c", "alembic upgrade head; uvicorn app.main:app --host 0.0.0.0 --port 8000"]
