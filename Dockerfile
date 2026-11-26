# syntax=docker/dockerfile:1.14
FROM python:3.12-slim-bookworm@sha256:44cf1793efa7c7a476bb0f2cff81443f4a072c90c1cb127e2924933daa3e8c64

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    STREAMLIT_SERVER_ADDRESS=0.0.0.0 \
    STREAMLIT_SERVER_HEADLESS=true \
    STREAMLIT_SERVER_PORT=8501 \
    STREAMLIT_BROWSER_GATHER_USAGE_STATS=false

WORKDIR /app
COPY requirements.lock .
RUN python -m pip install --no-cache-dir --no-compile --require-hashes -r requirements.lock \
    && groupadd --gid 10001 streamlit \
    && useradd --uid 10001 --gid 10001 --create-home streamlit

COPY --chmod=u=rwX,go=rX . .

USER 10001:10001
EXPOSE 8501
HEALTHCHECK --interval=30s --timeout=3s --start-period=30s \
    CMD ["python", "-c", "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8501/_stcore/health', timeout=2).close()"]
CMD ["streamlit", "run", "app.py"]
