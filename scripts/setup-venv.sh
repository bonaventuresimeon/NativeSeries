#!/usr/bin/env bash
set -euo pipefail

cd "$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"

PY=python3
$PY -m venv .venv
source .venv/bin/activate
pip install --upgrade pip setuptools wheel
if [[ -f requirements.txt ]]; then
  pip install -r requirements.txt
fi
python -V
pip -V