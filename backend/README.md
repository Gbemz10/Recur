# Recur Backend

FastAPI backend for Recur.

## Local Development

Install dependencies:

```bash
python -m venv .venv
.venv\Scripts\pip install -e ".[dev]"
```

Run the API:

```bash
.venv\Scripts\uvicorn backend.app.main:app --reload
```

Run tests:

```bash
.venv\Scripts\pytest
```
