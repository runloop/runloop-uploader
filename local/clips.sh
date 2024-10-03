#!/usr/bin/env bash

set -eo pipefail

SCRIPT_DIR=$(dirname "$(realpath "$0")")

show_help() {
  echo "Usage: clips.sh [options]"
  echo "Options:"
  echo "  -s <server-name>   The server instance ID"
  echo "  -k <stream-key>    The stream key (required)"
  echo "  -u <location>      The directory url of the clips"
  echo "  -n <max-clips>     The max number of clips to include (Optional)"
  echo "  -i <include>       Pattern to limit which files are included"
  echo "  -x <exclude>       Pattern to exclude from file names (ex. \"halloween\|xmas\|new-year\")"
  echo "  -a <audio-file>    Google storage URL for audio file"
  echo "  -d <duration>      The duration of the stream (optional)"
  echo "  -h                 Show this help message"
}

# Default values
SERVER_ID=""
STREAM_KEY=""
MAX_CLIPS="30"
INCLUDE_PATTERN=""
EXCLUDE_PATTERN=""
AUDIO_GS_URL=""
DURATION=""
LOCATION=""

while getopts ":s:k:n:i:x:a:d:u:h" opt; do
  case ${opt} in
    s )
      SERVER_ID=$OPTARG
      ;;
    k )
      STREAM_KEY=$OPTARG
      ;;
    n )
      MAX_CLIPS=$OPTARG
      ;;
    i )
      INCLUDE_PATTERN=$OPTARG
      ;;
    x )
      EXCLUDE_PATTERN=$OPTARG
      ;;
    a )
      AUDIO_GS_URL=$OPTARG
      ;;
    d )
      DURATION=${OPTARG}
      ;;
    u )
      LOCATION=${OPTARG}
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

if [ -z "${LOCATION}" ]; then
  echo "You must provide a location using the option -u"
  show_help
  exit 1
fi

# Check if -k was provided
if [ -z "${STREAM_KEY}" ]; then
  echo "You must provide a stream key using the option -k"
  show_help
  exit 1
fi

# Check if -a was provided
if [ -z "${AUDIO_GS_URL}" ] || [[ ! "${AUDIO_GS_URL}" =~ \.m4a$ ]]; then
  echo "You must provide a valid .m4a audio file URL using the option -a"
  show_help
  exit 1
fi

# Check if -d flag is a number zero or greater
if ! [[ "${DURATION}" =~ ^[0-9]+$ ]] || [ "${DURATION}" -lt 0 ]; then
    DURATION=0
fi

# if max clips is set but is not a number above 0 show the help
if ! [[ "${MAX_CLIPS}" =~ ^[0-9]+$ ]] || [ "${MAX_CLIPS}" -le 0 ]; then
  echo "You must provide a number above 0 when setting the -n flag"
  show_help
  exit 1
fi

echo "bash /usr/local/clips.sh -k ${STREAM_KEY} -u \"${LOCATION}\" -i \"${INCLUDE_PATTERN}\" -x \"${EXCLUDE_PATTERN}\" -a \"${AUDIO_GS_URL}\" -d ${DURATION} -n ${MAX_CLIPS}"

gcloud storage cp "${SCRIPT_DIR}/../server/render-functions.sh" gs://runloop-videos/000-stream-assets/scripts/render-functions.sh
gcloud compute scp "${SCRIPT_DIR}/../server/clips.sh" "${SERVER_ID}:~/clips.sh"
gcloud compute ssh "${SERVER_ID}" --command "bash ~/clips.sh -k \"${STREAM_KEY}\" -u \"${LOCATION}\" -i \"${INCLUDE_PATTERN}\" -x \"${EXCLUDE_PATTERN}\" -a \"${AUDIO_GS_URL}\" -d ${DURATION} -n ${MAX_CLIPS}"
