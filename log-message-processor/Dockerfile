FROM python:3.6-slim
WORKDIR /app

# Install build dependencies for compiling Python packages
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    g++ \
    python3-dev \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Remove build dependencies to reduce image size
RUN apt-get purge -y gcc g++ python3-dev && \
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

COPY . .
CMD ["python", "main.py"]