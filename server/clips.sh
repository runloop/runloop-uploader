#!/usr/bin/env bash

set -eo pipefail

show_help() {
  echo "Usage: clips.sh [options]"
  echo "Options:"
  echo "  -k <stream-key>    The stream key (required)"
  echo "  -u <location>      The directory url of the clips"
  echo "  -i <include>       Pattern to limit which files are included"
  echo "  -n <max-clips>     The max number of clips to include (Optional)"
  echo "  -x <exclude>       Pattern to exclude from file names (ex. \"halloween\|xmas\|new-year\")"
  echo "  -a <audio-file>    Google storage URL for audio file (optional)"
  echo "  -d <duration>      The duration of the stream (optional)"
  echo "  -h                 Show this help message"
}

# Default values
STREAM_KEY=""
INCLUDE_PATTERN=""
EXCLUDE_PATTERN=""
AUDIO_GS_URL=""
DURATION=""
MAX_CLIPS="30"
LOCATION=""

while getopts ":k:n:i:x:a:d:u:h" opt; do
  case ${opt} in
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

main() {
  source /usr/local/render-functions.sh
  refresh_functions
  source /usr/local/render-functions.sh
  screen_kill stream
  stream_clean
  download_audio "${AUDIO_GS_URL}"

  if [ -n "${INCLUDE_PATTERN}" ]; then
    file_list=$(list_files_including "${LOCATION}" "${MAX_CLIPS}" "${INCLUDE_PATTERN}")
  elif [ -n "${EXCLUDE_PATTERN}" ]; then
    file_list=$(list_files_excluding "${LOCATION}" "${MAX_CLIPS}" "${EXCLUDE_PATTERN}")
  else
    file_list=$(list_files "${LOCATION}" "${MAX_CLIPS}")
  fi

  download_clips "${file_list}"
  generate_files_txt
  compilation_stream_files "${STREAM_KEY}" "${DURATION}"
}

main