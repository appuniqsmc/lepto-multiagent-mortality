# Changelog

## 1.0.0 — Initial repository release

Migrated from the original Google Colab research notebook
(`Lepto_MultiAgent_AI.ipynb`) to a modular, tested, containerized Python
package. Changes made during migration:

### Security
- **Removed a hardcoded Groq API key** that was present in two notebook
  cells. The key is no longer stored anywhere in this repository; it must
  be supplied via the `GROQ_API_KEY` environment variable. Anyone who had
  access to the original notebook file should rotate that key.

### Scope
- Excluded baseline machine-learning comparator code (logistic regression,
  random forest, XGBoost) and other exploratory cells from the original
  notebook, so this repository contains only the multi-agent LLM pipeline
  described in the manuscript.

### Bug fixes
- **Figure 3 (mortality-probability distribution) was blank in the
  original notebook output.** The original notebook cell called
  `plt.savefig()` in a later cell than the one that drew the histogram
  (`plt.hist(...)` + `plt.show()`), and `plt.show()` clears the current
  figure — so the saved PNG was empty. `figures.py::figure3_distribution`
  draws and saves within a single function call, fixing this.
- Fixed a column-naming inconsistency in the failure-mode analysis
  (`majority_vote()` / `dissent_case_analysis()`) between raw agent-output
  columns and their parsed `*_pred` counterparts, which had silently
  produced zero dissent cases during initial testing of this repository's
  `compute_statistics.py` script. Caught by re-validating against the
  original study's results CSV before release; see `tests/test_failure_mode.py`.

### Engineering additions not present in the original notebook
- Resumable batch pipeline (checkpoint/skip already-processed patients).
- Retry-with-backoff on transient API failures.
- Structured, multi-stage JSON parsing with an explicit `UNKNOWN` fallback
  rather than silent failure.
- Unit tests, including regression tests against the exact confusion
  matrix and DeLong statistics reported in the manuscript.
- CI workflow (GitHub Actions) running the test suite on every push/PR.
- Docker and conda environments for reproducibility.
