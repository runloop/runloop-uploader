#!/usr/bin/env bash

set -eo pipefail

show_help() {
  echo "Usage: upload.sh [options]"
  echo "Options:"
  echo "  -k <stream-key>    The stream key (required)"
  echo "  -q <query>         The query to search for in project titles (required)"
  echo "  -m <music-dir>     Google storage URL for music directory (optional)"
  echo "  -a <audio-file>    Google storage URL for audio file (optional)"
  echo "  -h                 Show this help message"
}

# Default values
STREAM_KEY=""
QUERY=""
MUSIC_GS_URL=""
AUDIO_GS_URL=""

while getopts ":k:q:m:a:h" opt; do
  case ${opt} in
    k )
      STREAM_KEY=$OPTARG
      ;;
    q )
      QUERY=$OPTARG
      ;;
    m )
      MUSIC_GS_URL=$OPTARG
      ;;
    a )
      AUDIO_GS_URL=$OPTARG
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

gsls() {
  if [[ $# -ne 1 ]]; then
    echo "Usage: gsls <search-string>"
    return 1
  fi

  declare search_string="$1"

  # List root-level directories in the bucket and filter by the search string
  local results
  results=$(gsutil ls -d "gs://runloop-videos" | grep "${search_string}")

  if [[ -z "${results}" ]]; then
    echo "Error: Expected 1 result, but found 0"
    return 1
  fi

  echo "${results}"
}

get_id() {
  if [[ $# -ne 1 ]]; then
    echo "Usage: get_id <results>" >&2
    return 1
  fi

  declare results="$1"

  # Check if the results is empty
  if [ -z "$results" ]; then
      echo "Error: No results provided" >&2
      return 1
  fi

  # Count the number of results
  local count
  count=$(echo "${results}" | wc -l)

  if [[ "${count}" -eq 1 ]]; then
    # Extract and return the directory name
    local dir_name
    dir_name=$(basename "${results}")
    echo "${dir_name}"
  else
    echo "Error: Expected 1 result, but found ${count}:" >&2
    echo "${results}" >&2
    return 1
  fi
}

screen_kill() {
  declare screen_id="$1"
  screen -S "${screen_id}" -p 0 -X quit
}

download_music_files() {
  declare stream_key="$1" music_gs_url="$2"
  local path
  path="./${stream_key}/stream-assets/music"
  # create a directory within the stream key directory to hold the music
  mkdir -p "${path}"
  # download the music into that directory
  gcloud storage cp -r "${music_gs_url}/*" "./${stream_key}/stream-assets/music"
  echo "${path}"
}

create_music_files_list() {
  declare stream_key="$1" music_path="$2"
  local result
  result="${stream_key}/stream-assets/files.txt"
  # find all the mp3s and make a file list that ffmpeg can read
#  find "${music_path}" -name '*.mp3' | shuf | awk '{print "file '\''" $0 "'\''"}' > "${result}"
  find "${music_path}" -name '*.mp3' -print0 | shuf -z | xargs -0 realpath | awk '{print "file '\''" $0 "'\''"}' > "${result}"
  echo "${result}"
}

download_audio_file() {
  declare stream_key="$1" audio_gs_url="$2"
  local path
  path="./${stream_key}/stream-assets"
  # create a directory within the stream key directory to hold the music
  mkdir -p "${path}"
  # download the music into that directory
  gcloud storage cp "${audio_gs_url}" "${path}/audio.mp3"

  local file_path
  file_path=$(realpath "${path}/audio.mp3")
  echo "${file_path}"
}

stream_video_only() {
  declare stream_key="$1"
  echo "stream_video_only stream_key=${stream_key}"
  screen -dmS "${stream_key}" ffmpeg -re -stream_loop -1 -i "${stream_key}/loop.mov" -c copy -bufsize 10000k \
    -method POST -f hls -ignore_io_errors 1 \
    "https://a.upload.youtube.com/http_upload_hls?cid=${stream_key}&copy=0&file=index.m3u8"
}

stream_video_audio() {
  declare stream_key="$1" audio_gs_url="$2"
  echo "stream_video_audio stream_key=${stream_key} audio_gs_url=${audio_gs_url}"
  local video_file
  local audio_file

  video_file=$(realpath "${stream_key}/loop.mov")

  # download audio
  audio_file=$(download_audio_file "${stream_key}" "${audio_gs_url}")

  screen -dmS "${stream_key}" ffmpeg -re -stream_loop -1 -i "${video_file}" -stream_loop -1 \
    -i "${audio_file}" -map 0:v -map 1:a -c:v copy -c:a copy -bufsize 10000k -method POST -f hls -ignore_io_errors 1 \
    "https://a.upload.youtube.com/http_upload_hls?cid=${stream_key}&copy=0&file=index.m3u8"
}

stream_video_music() {
  declare stream_key="$1" music_gs_url="$2"
  echo "stream_video_music stream_key=${stream_key} music_gs_url=${music_gs_url}"
  local music_path
  local files_list

  # download music directory
  music_path=$(download_music_files "${stream_key}" "${music_gs_url}")

  # create music file
  files_list=$(create_music_files_list "${stream_key}" "${music_path}" )

  screen -dmS "${stream_key}" ffmpeg -re -stream_loop -1 -i "${stream_key}/loop.mov" -stream_loop -1 -f concat -safe 0 \
    -i "${files_list}" -map 0:v -map 1:a -c:v copy -c:a copy -bufsize 10000k -method POST -f hls -ignore_io_errors 1 \
    "https://a.upload.youtube.com/http_upload_hls?cid=${stream_key}&copy=0&file=index.m3u8"
}

stream_video_audio_music() {
  declare stream_key="$1" audio_gs_url="$2" music_gs_url="$3"
  echo "stream_video_audio_music stream_key=${stream_key} audio_gs_url=${audio_gs_url} music_gs_url=${music_gs_url}"
  local audio_file
  local music_path
  local files_list

  # download audio
  audio_file=$(download_audio_file "${stream_key}" "${audio_gs_url}")

  # download music directory
  music_path=$(download_music_files "${stream_key}" "${music_gs_url}")

  # create music file
  files_list=$(create_music_files_list "${stream_key}" "${music_path}" )

  screen -dmS "${stream_key}" ffmpeg -re -stream_loop -1 -i "${stream_key}/loop.mov" -stream_loop -1 -f concat -safe 0 \
    -i "${files_list}" -stream_loop -1 -i "${audio_file}" \
    -filter_complex "[1:a]volume=0.8[a1];[2:a]volume=0.8[a2];[a1][a2]amerge=inputs=2[a]" -map 0:v -map "[a]" \
    -c:v copy -c:a aac -b:a 128k -ac 2 -bufsize 10000k -method POST -f hls -ignore_io_errors 1 \
    "https://a.upload.youtube.com/http_upload_hls?cid=${stream_key}&copy=0&file=index.m3u8"
}

main () {
  declare stream_key="$1" query="$2" music_gs_url="$3" audio_gs_url="$4"

  # clean up any streams that are using this stream key
  clean_up "${stream_key}" || true

  # search for project
  local search_results
  search_results=$(gsls "${query}")

  # find project id
  local project_id
  project_id=$(get_id "${search_results}")

  # create new directory for stream_key
  mkdir -p "${stream_key}"

  # download project files
  gcloud storage cp -r "gs://runloop-videos/${project_id}/*" "./${stream_key}"

  if [[ -z "${music_gs_url}" && -z "${audio_gs_url}" ]]; then
    stream_video_only "${stream_key}"
  elif [[ -z "${music_gs_url}" && -n "${audio_gs_url}" ]]; then
    stream_video_audio "${stream_key}" "${audio_gs_url}"
  elif [[ -n "${music_gs_url}" && -z "${audio_gs_url}" ]]; then
    stream_video_music "${stream_key}" "${music_gs_url}"
  else
    stream_video_audio_music "${stream_key}" "${audio_gs_url}" "${music_gs_url}"
  fi
}

clean_up() {
  declare stream_key="$1"

  # kill any screens that are active with the stream_key
  screen_kill "${stream_key}" || true

  # remove any project files associated with the stream_key
  rm -fr "${stream_key}"
}

# Check if -k was provided
if [ -z "${STREAM_KEY}" ]; then
  echo "You must provide a stream key using the option -k"
  show_help
  exit 1
fi

# Check if -q was provided if not clean up and exit
if [ -z "${QUERY}" ]; then
  clean_up "${STREAM_KEY}"
  exit 0
fi

# regex for a valid bucket url
readonly bucket_regex="^gs:\/\/[a-z0-9][-a-z0-9_.]{1,61}[a-z0-9]\/.+$"

# Check that the music dir is a valid bucket URL only if it has been set
if [[ -n $MUSIC_GS_URL && ! $MUSIC_GS_URL =~ $bucket_regex ]]; then
  echo "The music directory must be a valid Google Storage bucket URL"
  show_help
  exit 1
fi

# Check that the audio file is a valid bucket URL only if it has been set
if [[ -n $AUDIO_GS_URL && ! $AUDIO_GS_URL =~ $bucket_regex ]]; then
  echo "The audio file must be a valid Google Storage bucket URL"
  show_help
  exit 1
fi

main "${STREAM_KEY}" "${QUERY}" "${MUSIC_GS_URL}" "${AUDIO_GS_URL}"


