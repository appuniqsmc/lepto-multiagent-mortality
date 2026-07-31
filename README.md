# Hierarchical Multi-Agent LLM Pipeline for ICU Mortality Prediction in Severe Leptospirosis

This repository contains the reference implementation of the seven-stage hierarchical multi-agent large language model (LLM) pipeline described in the accompanying manuscript, *"Hierarchical Multi-Agent Large Language Models for ICU Mortality Prediction in Severe Leptospirosis: Discrimination, Calibration, and a Failure Mode in Specialist Synthesis."*

It contains **only the multi-agent LLM implementation and its statistical analysis**. Baseline machine-learning comparator models (logistic regression, random forest, XGBoost) and other exploratory notebook experiments from the original research notebook are intentionally excluded, so that this repository aligns directly with the methods described in the paper.

> **Terminology note.** Throughout this codebase and the manuscript, "agent" refers to a single, isolated LLM inference call constrained by a fixed role-specific prompt — not an autonomous, tool-using, or self-planning system. See the manuscript Methods, "Definition of Agent," for the full rationale.

---

## Architecture

```
                 Structured patient data (64 clinical variables)
                                    |
        ┌───────────┬───────────┬──┴──────────┬──────────────────┐
        ▼           ▼           ▼              ▼                  ▼
  Cardiology   Nephrology   Pulmonology    Hematology     Infectious Disease
   (agent)      (agent)      (agent)        (agent)            (agent)
        └───────────┴───────────┬──────────┴──────────────────┘
                                 ▼
                          Intensivist agent
                     (integration step — see note)
                                 ▼
                            Judge agent
                       (final decision step)
                                 ▼
                  Final mortality prediction + probability
```

Each of the five specialist agents receives the **complete** structured patient record (not a filtered subset) but is instructed, via its prompt, to reason only within its assigned specialty. No specialist sees another specialist's output. The Intensivist agent receives all five specialist outputs; the Judge agent receives all five specialist outputs plus the Intensivist's output.

**Note on the Intensivist agent:** this pipeline's exploratory analysis (see `scripts/compute_statistics.py` → `failure_mode_analysis`, and the manuscript Results/Discussion) found that, in the original study run, the Intensivist's predictions tracked simple specialist majority vote in 74% of cases and significantly underperformed the single best specialist agent (paired DeLong p = 0.0087). The code and prompts here therefore describe it neutrally as an "integration step" rather than assuming it performs effective synthesis — that is an empirical question this repository lets you re-test, not a property built into its design.

---

## Repository structure

```
lepto-multiagent-mortality/
├── README.md
├── LICENSE
├── requirements.txt
├── environment.yml
├── Dockerfile
├── pyproject.toml
├── .env.example
├── .gitignore
├── config/
│   └── config.yaml            # model, prompts, paths, statistics settings
├── prompts/                    # externalized prompt templates (one file per agent)
│   ├── patient_template.txt
│   ├── cardiology.txt
│   ├── nephrology.txt
│   ├── pulmonology.txt
│   ├── hematology.txt
│   ├── infectious_disease.txt
│   ├── intensivist.txt
│   └── judge.txt
├── src/lepto_multiagent/
│   ├── config.py               # YAML + environment-variable configuration
│   ├── logging_utils.py
│   ├── llm_client.py           # Groq API wrapper with retry/backoff
│   ├── parsing.py              # robust structured-JSON parsing with UNKNOWN fallback
│   ├── patient.py              # patient-record -> prompt text formatting
│   ├── agents.py                # the seven agent classes
│   ├── pipeline.py             # resumable batch inference orchestration
│   ├── results_io.py           # loads/parses a results CSV into structured columns
│   ├── figures.py              # generates manuscript Figures 1-5
│   └── stats/
│       ├── metrics.py          # accuracy/sensitivity/specificity, bootstrap AUROC CIs, calibration
│       ├── delong.py           # paired DeLong test (Sun & Xu, 2014)
│       └── failure_mode.py     # majority-vote / specialist-dissent analysis
├── scripts/
│   ├── run_pipeline.py         # CLI: run inference over a patient CSV
│   ├── compute_statistics.py   # CLI: compute all manuscript statistics -> JSON
│   └── generate_figures.py     # CLI: generate Figures 1-5 from a results CSV
├── tests/                      # unit tests, incl. regression tests against
│                                # reported manuscript numbers
├── data/
│   ├── raw/                    # place input patient CSV here (not tracked in git)
│   └── processed/
└── results/                    # pipeline outputs land here (not tracked in git)
```

---

## Installation

### Option A: pip
```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

### Option B: conda
```bash
conda env create -f environment.yml
conda activate lepto-multiagent
```

### Option C: Docker
```bash
docker build -t lepto-multiagent .
```

---

## Configuration

All non-secret settings (model name, temperature, prompt/data paths, bootstrap iterations, etc.) live in `config/config.yaml`.

**The API key is never read from a config file or hardcoded in source.** It is read exclusively from the `GROQ_API_KEY` environment variable:

```bash
cp .env.example .env
# edit .env and fill in your real key
export $(grep -v '^#' .env | xargs)
```

> **Security note:** an earlier working version of this pipeline (the original research notebook) had a live API key hardcoded in two cells. If you are migrating from that notebook, **rotate that key** at your provider's console before reusing it here — a key that ever appeared in a notebook file, git history, or shared document should be treated as compromised.

---

## Usage

### 1. Run the inference pipeline
```bash
python scripts/run_pipeline.py \
    --input data/raw/patients.csv \
    --output results/MultiAgent_Results.csv
```
- Resumable: re-running with the same `--output` path skips patients already present in that file.
- Use `--limit 5` to smoke-test on the first 5 patients before committing to a full run.
- Required input columns are listed in `config/config.yaml` under `pipeline.required_fields`, plus an ID column and an outcome column (see `pipeline.id_column`, `pipeline.outcome_column`).

### 2. Compute statistics
```bash
python scripts/compute_statistics.py \
    --results results/MultiAgent_Results.csv \
    --output results/statistics_summary.json
```
Computes, per the manuscript Methods (Sections 9–10): fixed-threshold classification metrics, continuous-score AUROC with bootstrap 95% CIs for each of the 5 specialists + Intensivist + final Judge output, paired DeLong tests between the best specialist / Intensivist / Judge, and the majority-vote dissent-case failure-mode analysis.

### 3. Generate figures
```bash
python scripts/generate_figures.py \
    --results results/MultiAgent_Results.csv \
    --output-dir results/figures
```
Produces Figures 1–5 (ROC curve, confusion matrix, probability distribution, boxplot by outcome, calibration plot) as 300-dpi PNGs.

### Docker equivalent
```bash
docker run --rm -e GROQ_API_KEY=your_key \
    -v $(pwd)/data:/app/data -v $(pwd)/results:/app/results \
    lepto-multiagent scripts/run_pipeline.py \
        --input data/raw/patients.csv --output results/MultiAgent_Results.csv
```

---

## Testing

```bash
pytest tests/ -v
```
Includes regression tests that reproduce the exact confusion matrix and DeLong statistics reported in the manuscript, using fixture/synthetic data (no API key required — these tests never call the LLM).

---

## Data availability

**No patient data is included in this repository.** The original clinical dataset (116 ICU patients with severe leptospirosis) is available on zenodo

---

## Reproducibility notes

- All seven agents use the same underlying model (`openai/gpt-oss-120b` via the Groq API) and fixed decoding parameters (temperature 0.2), per manuscript Methods Section 7.
- **Each patient's pipeline was executed once** in the original study; LLM outputs can vary between runs even at fixed temperature, so exact replication of specific per-patient predictions (and therefore the small-sample failure-mode counts in Results Section 5) is not guaranteed across reruns. This is stated explicitly as a limitation in the manuscript.
- Five of 116 Judge outputs in the original run did not contain a valid, parseable `final_prediction` field and were excluded from binary-classification metrics (not imputed) — see `parsing.py::is_unknown_final` and manuscript Methods Section 9.1.
- Statistical methods (bootstrap AUROC CIs, paired DeLong test) are implemented independently in `src/lepto_multiagent/stats/` with unit tests against known values; see `tests/`.

---

## Citation

If you use this code, please cite the accompanying manuscript:

```
[Author list]. Hierarchical Multi-Agent Large Language Models for ICU Mortality
Prediction in Severe Leptospirosis: Discrimination, Calibration, and a Failure
Mode in Specialist Synthesis. [Journal, year, DOI once available].
```


---

## License

Code is released under the MIT License (see `LICENSE`). This license applies to the software only and does not extend to any clinical data, which remains governed by institutional ethics approval and data use agreements.

---

## Ethical use statement

This code is provided for research and reproducibility purposes only. It is **not validated for, and must not be used for, real-time clinical decision-making**. See the manuscript's Limitations section for a full discussion of the exploratory, hypothesis-generating nature of these findings.
