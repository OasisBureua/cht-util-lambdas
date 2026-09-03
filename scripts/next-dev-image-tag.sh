#!/usr/bin/env bash
exec "$(dirname "$0")/next-image-tag.sh" "${1:?repository name required}" "${2:-us-east-1}"
