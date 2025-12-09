
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


COPY ./requirements.txt /app/


RUN pip install --no-cache-dir pyyaml>=6.0 \
    && pip install --no-cache-dir -r /app/requirements.txt --no-deps
