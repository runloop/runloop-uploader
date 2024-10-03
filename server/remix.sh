#!/usr/bin/env bash

set -eo pipefail

show_help() {
  echo "Usage: clips.sh [options]"
  echo "Options:"
  echo "  -k <stream-key>    The stream key (required)"
  echo "  -d <duration>      The duration of the stream (optional)"
  echo "  -h                 Show this help message"
}

# Default values
STREAM_KEY=""
DURATION=""

while getopts ":k:d:h" opt; do
  case ${opt} in
    k )
      STREAM_KEY=$OPTARG
      ;;
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

# Check if -k was provided
if [ -z "${STREAM_KEY}" ]; then
  echo "You must provide a stream key using the option -k"
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
  screen_kill stream
  generate_files_txt
  compilation_stream_files "${STREAM_KEY}" "${DURATION}"
}

main