FROM python:3.12-slim AS builder
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir --user -r requirements.txt

FROM python:3.12-slim AS runner
WORKDIR /app
RUN groupadd -g 1000 appuser && useradd -u 1000 -g appuser -s /bin/bash -m appuser
COPY --from=builder /root/.local /home/appuser/.local
COPY . /app/
ENV PATH=/home/appuser/.local/bin:$PATH
ENV PYTHONUNBUFFERED=1
USER appuser
EXPOSE 8102
CMD ["python3", "-m", "uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8102"]
