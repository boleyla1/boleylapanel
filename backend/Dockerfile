FROM python:3.12-bullseye

WORKDIR /code




COPY ./requirements.txt /code/

RUN python3 -m pip install --upgrade pip setuptools \
 && pip install --no-cache-dir -r /code/requirements.txt

COPY . /code

EXPOSE 8000

CMD ["python3", "main.py"]
