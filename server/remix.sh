#!/usr/bin/env bash

set -eo pipefail

show_help() {
  echo "Usage: clips.sh [options]"
  echo "Options:"
  echo "  -d <duration>      The duration of the stream (optional)"
  echo "  -h                 Show this help message"
}

# Default values
DURATION=""

while getopts ":d:h" opt; do
  case ${opt} in
    d )
      DURATION=${OPTARG}
      ;;
    h )
      show_help
      exit 0
      ;;
    \? )
      echo "Invalid option: -$OPTARG" 1>&2
      show_help
      exit 1
      ;;
    : )
      echo "Option -$OPTARG requires an argument" 1>&2
      show_help
      exit 1
      ;;
  esac
done

# Check if stream key is defined
if [ -z "${STREAM_KEY}" ]; then
  echo "Error: STREAM_KEY must be defined in /etc/environment"
  show_help
  exit 1
fi

# Check if -d flag is a number zero or greater
if ! [[ "${DURATION}" =~ ^[0-9]+$ ]] || [ "${DURATION}" -lt 0 ]; then
    DURATION=0
fi

main() {
  source /usr/local/render-functions.sh
  refresh_functions
  source /usr/local/render-functions.sh
  screen_kill stream || true
  generate_files_txt
  compilation_stream_files "${STREAM_KEY}" "${DURATION}"
}

main