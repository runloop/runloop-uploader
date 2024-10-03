#!/usr/bin/env bash

set -eo pipefail

SCRIPT_DIR=$(dirname "$(realpath "$0")")

show_help() {
  echo "Usage: clips.sh [options]"
  echo "Options:"
  echo "  -s <server-name>   The server instance ID"
  echo "  -k <stream-key>    The stream key (required)"
  echo "  -d <duration>      The duration of the stream (optional)"
  echo "  -h                 Show this help message"
}

# Default values
SERVER_ID=""
STREAM_KEY=""
DURATION=""

while getopts ":s:k:d:h" opt; do
  case ${opt} in
    s )
      SERVER_ID=$OPTARG
      ;;
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

# Check if -i <instance-name> was provided
if [ -z "${SERVER_ID}" ]; then
  echo "You must provide the instance name using the option -s"
  show_help
  exit 1
fi

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

gcloud storage cp "${SCRIPT_DIR}/../server/render-functions.sh" gs://runloop-videos/000-stream-assets/scripts/render-functions.sh
gcloud compute scp "${SCRIPT_DIR}/../server/remix.sh" "${SERVER_ID}:~/remix.sh"
gcloud compute ssh "${SERVER_ID}" --command "bash ~/remix.sh -k \"${STREAM_KEY}\" -d ${DURATION}"
