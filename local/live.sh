#!/usr/bin/env bash

set -eo pipefail

SCRIPT_DIR=$(dirname "$(realpath "$0")")

show_help() {
  echo "Usage: live.sh [options]"
  echo "Options:"
  echo "  -i <instance-name> The instance ID"
  echo "  -k <stream-key>    The stream key (required)"
  echo "  -q <query>         The query to search for in project titles (required)"
  echo "  -m <music-dir>     Google storage URL for music directory (optional)"
  echo "  -v <volume>        The volume the original video should play at (optional)"
  echo "  -a <audio-file>    Google storage URL for audio file (optional)"
  echo "  -l <loop-file>     The name of the file we intend to loop (optional)"
  echo "  -d <duration>      The duration of the stream (optional)"
  echo "  -h                 Show this help message"
}

# Default values
INSTANCE_NAME=""
STREAM_KEY=""
QUERY=""
MUSIC_GS_URL=""
VIDEO_VOLUME=""
AUDIO_GS_URL=""
LOOP_FILE="loop.mov"
DURATION=""

while getopts ":i:k:q:m:v:a:l:d:h" opt; do
  case ${opt} in
    i )
      INSTANCE_NAME=$OPTARG
      ;;
    k )
      STREAM_KEY=$OPTARG
      ;;
    q )
      QUERY=$OPTARG
      ;;
    m )
      MUSIC_GS_URL=$OPTARG
      ;;
    v )
      VIDEO_VOLUME="-v ${OPTARG}"
      ;;
    a )
      AUDIO_GS_URL=$OPTARG
      ;;
    l )
      LOOP_FILE=$OPTARG
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
if [ -z "${INSTANCE_NAME}" ]; then
  echo "You must provide the instance name using the option -i"
  show_help
  exit 1
fi

# Check if -k was provided
if [ -z "${STREAM_KEY}" ]; then
  echo "You must provide a stream key using the option -k"
  show_help
  exit 1
fi

# Check if -d flag is a number above zero
DURATION_FLAG=""
if [[ "${DURATION}" =~ ^[0-9]+$ ]] && [ "${DURATION}" -gt 0 ]; then
    DURATION_FLAG="-d ${DURATION}"
fi

gcloud compute scp "${SCRIPT_DIR}/../server/live.sh" "${INSTANCE_NAME}:~/live.sh"
gcloud compute ssh "${INSTANCE_NAME}" --command "bash ~/live.sh -k \"${STREAM_KEY}\" -l \"${LOOP_FILE}\" -q \"${QUERY}\" -a \"${AUDIO_GS_URL}\" -m \"${MUSIC_GS_URL}\" ${VIDEO_VOLUME} ${DURATION_FLAG}"

# alias pg1="bash ~/dev/runloop-uploader.sh -i stream-pg12 -k key1 -q"
# alias pg1_classics="bash ~/dev/runloop-uploader.sh -i stream-pg12 -k key1 -m gs://.../classics -q"

# alias pg1_classics="bash ~/dev/runloop-uploader.sh -i stream-pg12 -k key1 -m gs://runloop-videos/000-stream-assets/music/classics -q"

# bash ~/dev/runloop-uploader.sh -i stream-pg12 -k key1 -m gs://runloop-videos/000-stream-assets/music/classics -q


# bash ~/dev/runloop-uploader.sh -i hh12 -k key1 -m gs://runloop-videos/000-stream-assets/music/classics -a gs://runloop-videos/000-stream-assets/sfx/forest-sounds-loop.mp3 -q


# bash ~/dev/runloop-uploader/local/live.sh -i hh12 -k 1t68-c6h2-p5tj-rfhx-1dwv -m gs://runloop-videos/000-stream-assets/music/classics -a gs://runloop-videos/000-stream-assets/sfx/forest-sounds-loop.mp3 -q