FROM python:3.13

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

RUN apt update && apt install build-essential -y
RUN pip install uv

COPY pyproject.toml /app/
COPY uv.lock /app/

WORKDIR /app
RUN uv sync --locked

RUN groupadd --gid 1000 appuser && useradd --uid 1000 --gid appuser --shell /bin/bash --create-home appuser && chown -R appuser:appuser /app
USER appuser

COPY src /app/

CMD ["uv", "run", "garmin_grafana/garmin_fetch.py"]
