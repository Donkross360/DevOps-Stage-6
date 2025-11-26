FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
CMD ["python", "processor.py"]
```

**Redis - Use official image**
```yaml
# In docker-compose.yml
redis:
  image: redis:7-alpine
  ports:
    - "6379:6379"