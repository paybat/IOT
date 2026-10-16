#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
project_dir="$(cd -- "$script_dir/.." && pwd)"

export VAGRANT_DOTFILE_PATH="${VAGRANT_DOTFILE_PATH:-${HOME}/.vagrant-p1}"
cd "$project_dir"
exec vagrant "$@"
