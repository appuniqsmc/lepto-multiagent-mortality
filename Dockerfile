# Lepto Multi-Agent Mortality Prediction Pipeline
# Build:  docker build -t lepto-multiagent .
# Run:    docker run --rm -e GROQ_API_KEY=your_key -v $(pwd)/data:/app/data -v $(pwd)/results:/app/results lepto-multiagent \
#             python scripts/run_pipeline.py --input data/raw/patients.csv --output results/MultiAgent_Results.csv

FROM python:3.11-slim

WORKDIR /app

# System dependencies for matplotlib (headless rendering) and general builds
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

# API keys must be supplied at runtime via -e GROQ_API_KEY=..., never baked
# into the image.
ENV PYTHONUNBUFFERED=1
ENV MPLBACKEND=Agg

ENTRYPOINT ["python"]
CMD ["scripts/run_pipeline.py", "--help"]
