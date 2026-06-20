#!/usr/bin/env bash
# snap-now.sh — snapshot manual instantáneo con snapper.
# Uso: ./snap-now.sh "antes de probar el find ese"
set -euo pipefail
DESC="${1:-snapshot manual}"
sudo snapper -c root create --description "$DESC"
echo "Snapshot creado. Lista de snapshots:"
sudo snapper -c root list
