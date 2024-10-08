#!/usr/bin/env bash

#set -eo pipefail

install_dependencies() {
  update_apt
  install_email
  install_ffmpeg
  install_python_libs
}

install_ffmpeg() {
  echo "Installing FFMPEG"
  sudo apt install -y ffmpeg
}

install_python_libs() {
  echo "Install python libs"
  sudo apt install -y python3-pip
  # install python libs
  pip3 install google-auth google-auth-oauthlib google-auth-httplib2 google-api-python-client
}

update_apt() {
  echo "Updating apt"
  sudo apt update
  sudo apt-get update
}

install_email() {
  echo "Installing ssmpt"
  local hostname
  # install the email client
  sudo apt-get install -y ssmtp
  # download the email credentials from Google Secrets Manager
  # this require the cloud-platform oauth access scope and Secret Manager Secret Accessor role on the service account
  sudo gcloud secrets versions access latest --secret=ssmtp_conf | sudo tee /etc/ssmtp/ssmtp.conf > /dev/null
  # get the hostname of this instance
  hostname=$(curl -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/hostname)
  # append the hostname to the ssmpt.conf file on a new line
  echo -e "\nhostname=${hostname}" | sudo tee -a /etc/ssmtp/ssmtp.conf > /dev/null
}

prepare_upload_script() {
  declare channel_code="$1"
  echo "Preparing upload script for ${channel_code}"
  # download the python script for uploading
  download_upload_script

  # download the correct metadata file (pg/hh)
  download_metadata "${channel_code}"

  # download the client-secret.json file for the runloop-uploader app
  download_client_secret

  # download the secret if it exists
  download_token "${channel_code}"
}

download_upload_script() {
  gsutil cp "gs://runloop-videos/000-stream-assets/scripts/upload.py" .
}

refresh_functions() {
  sudo gsutil cp "gs://runloop-videos/000-stream-assets/scripts/render-functions.sh" /usr/local/render-functions.sh
  source /etc/profile
  source ~/.profile
  echo "Render functions refreshed!"
}

download_metadata() {
  declare channel_code="$1"
  gsutil cp "gs://runloop-videos/000-stream-assets/scripts/${channel_code}-metadata.json" "./metadata.json"
}

download_client_secret() {
  gcloud secrets versions access latest --secret=client_secret_json > client-secret.json
}

download_token() {
  declare channel_code="$1"
  gcloud secrets versions access latest --secret="${channel_code}_token_json" > token.json
}

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

download_project_files() {
  echo "Downloading project files"
  declare search_term="$1"
  local search_results
  local search_term

  if ! search_results=$(gsls "$search_term"); then
    echo "$search_results" >&2
    return 1
  fi

  if ! search_term=$(get_id "$search_results"); then
    echo "$search_term" >&2
    return 1
  fi

  gcloud storage cp -r -n "gs://runloop-videos/${search_term}" ./
}

# Function to check if a file exists
check_file_exists() {
  declare path="$1"
  if [[ ! -f "${path}" ]]; then
    echo "Error: ${path} does not exist." >&2
    return 1
  fi
}

create_file_list() {
  echo "Creating file list"
  # Parameters with default values
  declare project_id="$1" intro_file="${2:-intro.mov}" path="${3:-files.txt}"

  local intro_path
  local loop_path
  intro_path=$(realpath "${project_id}/${intro_file}")
  loop_path=$(realpath "${project_id}/loop.mov")

  # Check if the repeat file exists
  if ! check_file_exists "${loop_path}"; then
    echo "Error: ${loop_path} does not exist" >&2
    return 0
  fi

  # Repeated value
  local loop_value="file '${loop_path}'"

  # Create the list
  {
    if check_file_exists "${intro_path}"; then
      echo "file '${intro_path}'"
    fi
    for i in {1..50}; do
      echo "$loop_value"
    done
  } > "${path}"
}

stream_full_video() {
  echo "Starting stream"
  declare file_list="$1" duration="${2:-10:00:00.00}"
  local stream_key
  stream_key="y9dh-p0my-4f1m-fgha-fsds"
  ffmpeg -re -f concat -safe 0 -i files.txt -c copy -t "${duration}" -bufsize 10000k -method POST -f hls -ignore_io_errors 1 "https://a.upload.youtube.com/http_upload_hls?cid=${stream_key}&copy=0&file=index.m3u8"
  local ffmpeg_status
  ffmpeg_status=$?
  if [ $ffmpeg_status -ne 0 ]; then
    return 1
  fi
}

#stream_comp() {
#  echo "Starting stream"
#  declare file_list="$1"
#  local stream_key
#  stream_key="jfsm-dar9-crcd-7e0u-1dkq"
#
#  ffmpeg -re -stream_loop -1 -f concat -safe 0 -i files.txt -c copy -bufsize 10000k -method POST -f hls -ignore_io_errors 1 \
#    "https://a.upload.youtube.com/http_upload_hls?cid=${stream_key}&copy=0&file=index.m3u8"
#
#  local ffmpeg_status
#  ffmpeg_status=$?
#  if [ $ffmpeg_status -ne 0 ]; then
#    return 1
#  fi
#}

render_full_video() {
  echo "Starting render"
  declare project_id="$1" duration="${2:-11:54:59.92}" file_list="${3:-files.txt}"
  ffmpeg -y -f concat -safe 0 -i "${file_list}" -c copy -t "${duration}" "${project_id}.mov"
  local ffmpeg_status
  ffmpeg_status=$?
  if [ $ffmpeg_status -ne 0 ]; then
    return 1
  fi
}

render_looped_video() {
  declare project_id="$1" duration="${2:-11:54:59.92}"
  ffmpeg -y -stream_loop -1 -i "${project_id}/loop.mov" -c copy -t "${duration}" "${project_id}.mov"
  local ffmpeg_status
  ffmpeg_status=$?
  if [ $ffmpeg_status -ne 0 ]; then
    return 1
  fi
}

stream_video_no_loop() {
  declare stream_key="$1" loop_file="$2"

  echo "stream_video_only stream_key=${stream_key}"
  ffmpeg -re -i "${loop_file}" -c copy -bufsize 10000k \
    -method POST -f hls -ignore_io_errors 1 \
    "https://a.upload.youtube.com/http_upload_hls?cid=${stream_key}&copy=0&file=index.m3u8"
}

download_pg_audio() {
  cd ~ || return
  mkdir -p media/clips
  gsutil cp gs://runloop-videos/000-stream-assets/sfx/pg-ambience-2024-04-25.m4a media/audio.m4a
}

pg_standard_compilation_prepare() {
  declare count="${1:-20}"
  cd ~ || return
  rm -fr compilation
  mkdir -p compilation/clips
  gsutil cp gs://runloop-videos/000-stream-assets/sfx/pg-ambience-2024-04-25.m4a compilation/audio.m4a
  # shellcheck disable=SC2046
  gsutil -m cp $(gsutil ls gs://runloop-videos/001-c-hdr-clips/standard | grep .mov | grep -v "halloween\|xmas\|new-year" | shuf -n "${count}" | tr '\n' ' ') ./compilation/clips
  exclude compilation/clips "" | shuf | ffmpeg_format files.txt
}

pg_eerie_compilation_prepare() {
  declare count="${1:-30}"
  cd ~ || return
  rm -fr compilation
  mkdir -p compilation/clips
  gsutil cp gs://runloop-videos/000-stream-assets/sfx/eerie-ambience.m4a compilation/audio.m4a
  # shellcheck disable=SC2046
  gsutil -m cp $(gsutil ls gs://runloop-videos/001-c-hdr-clips/halloween | grep .mov | shuf -n "${count}" | tr '\n' ' ') ./compilation/clips
  exclude compilation/clips "" | shuf | ffmpeg_format files.txt
}

pg_halloween_compilation_prepare() {
  declare count="${1:-30}"
  cd ~ || return
  rm -fr compilation
  mkdir -p compilation/clips
  gsutil cp gs://runloop-videos/000-stream-assets/sfx/pg-ambience-2024-04-25.m4a compilation/audio.m4a
  # shellcheck disable=SC2046
  gsutil -m cp $(gsutil ls gs://runloop-videos/001-c-hdr-clips/standard | grep "halloween" | shuf -n "${count}" | tr '\n' ' ') ./compilation/clips
  exclude compilation/clips "" | shuf | ffmpeg_format files.txt
}

pg_halloween_eerie() {
  declare count="${1:-25}"
  cd ~ || return
  rm -fr compilation
  mkdir -p compilation/clips
  gsutil cp gs://runloop-videos/000-stream-assets/sfx/eerie-ambience.m4a compilation/audio.m4a
  # shellcheck disable=SC2046
  gsutil -m cp $(gsutil ls gs://runloop-videos/001-c-hdr-clips/halloween | grep .mov | shuf -n "${count}" | tr '\n' ' ') ./compilation/clips
  exclude compilation/clips "" | shuf | ffmpeg_format files.txt
}

screen_kill() {
  declare screen_id="$1"
  screen -S "${screen_id}" -p 0 -X quit
}

stream_clean() {
  # kill any screens that are active with the stream_key
  cd ~ || return
  rm -fr compilation
  mkdir -p compilation/clips
}

download_audio() {
  declare url="$1"
  gsutil cp "${url}" compilation/audio.m4a
}

list_files_including() {
  declare url="$1" count="$2" query="$3"
  gsutil ls "${url}" | grep "${query}" | shuf -n "${count}"
}

list_files_excluding() {
  declare url="$1" count="$2" query="$3"
  gsutil ls "${url}" | grep .mov | grep -v "${query}" | shuf -n "${count}"
}

list_files() {
  declare url="$1" count="$2"
  gsutil ls "${url}" | shuf -n "${count}"
}

download_clips() {
  declare file_list="$1"
  # shellcheck disable=SC2046
  gsutil -m cp $(echo "${file_list}" | tr '\n' ' ') ./compilation/clips
}

generate_files_txt() {
  find ~/compilation/clips -type f -exec realpath {} \; | shuf | ffmpeg_format files.txt
}

pg_halloween_regular() {
  declare count="${1:-25}"
  stream_clean
  gsutil cp gs://runloop-videos/000-stream-assets/sfx/pg-ambience-2024-04-25.m4a compilation/audio.m4a
  # shellcheck disable=SC2046
  gsutil -m cp $(gsutil ls gs://runloop-videos/001-c-hdr-clips/standard | grep "halloween" | shuf -n "${count}" | tr '\n' ' ') ./compilation/clips
  exclude compilation/clips "" | shuf | ffmpeg_format files.txt
}



compilation_render() {
  ffmpeg -y -f concat -safe 0 -i files.txt -c copy "compilation/loop.mov"
}

compilation_stream_loop() {
  declare stream_key="$1"
  echo "Starting stream"

  screen -dmS stream ffmpeg -re -stream_loop -1 -i compilation/loop.mov -stream_loop -1 \
    -i compilation/audio.m4a -map 0:v -map 1:a -c:v copy -c:a copy -bufsize 10000k -method POST -f hls -ignore_io_errors 1 \
    "https://a.upload.youtube.com/http_upload_hls?cid=${stream_key}&copy=0&file=index.m3u8"


  local ffmpeg_status
  ffmpeg_status=$?
  if [ $ffmpeg_status -ne 0 ]; then
    return 1
  fi
}

compilation_stream_files() {
  declare stream_key="$1" duration="$2"

  local duration_flag=""
  if [[ "${duration}" =~ ^[0-9]+$ ]] && [ "${duration}" -gt 0 ]; then
    seconds=$((duration * 3600))
    duration_flag="-t ${seconds}"
  fi

  screen -dmS stream ffmpeg -re -stream_loop -1 -f concat -safe 0 -i files.txt -stream_loop -1 \
    -i compilation/audio.m4a -map 0:v -map 1:a -c:v copy -c:a copy ${duration_flag} -bufsize 10000k -method POST -f hls -ignore_io_errors 1 \
    "https://a.upload.youtube.com/http_upload_hls?cid=${stream_key}&copy=0&file=index.m3u8"

  local ffmpeg_status
  ffmpeg_status=$?
  if [ $ffmpeg_status -ne 0 ]; then
    return 1
  fi
}

pg_standard_stream() {
  declare count="${1:-25}" stream_key="$2"
  pg_standard_compilation_prepare "${count}"
  compilation_render
  compilation_stream_loop "${stream_key}"
}

pg_eerie_stream() {
  declare stream_key="$1"
  pg_halloween_eerie 25
  compilation_stream_files "${stream_key}"
}

#pg_eerie_stream() {
#  declare stream_key="$1"
#  pg_eerie_compilation_prepare 30
#  compilation_render
#  compilation_stream_loop "${stream_key}"
#}

pg_halloween_stream() {
  declare stream_key="$1"
  pg_halloween_compilation_prepare 30
  compilation_render
  compilation_stream_loop "${stream_key}"
}

upload_video() {
  declare video_file="$1" channel_code="$2"
  echo "Uploaded file: ${video_file}, to channel: ${channel_code}"
  # download the token to ensure it's always the freshest
  download_token "${channel_code}"
  # use the python script to upload the video file
  python_upload "${video_file}"
  # update to the token_json secret
  update_token_secret "${channel_code}"
}

down_stream() {
  declare project_id="$1" stream_key="${2:-y9dh-p0my-4f1m-fgha-fsds}"
  download_project_files "${project_id}"
  stream_video_no_loop "${stream_key}" "${project_id}/loop.mov"
  rm -fr "${project_id}"
}

downup() {
  declare project_id="$1" channel_code="${2:-pg}"
  prepare_for_render "${project_id}"
  upload_video "${project_id}-loop.mov" "${channel_code}"
  rm "${project_id}-loop.mov"
  rm -fr "${project_id}"
}

python_upload() {
  declare video_file="$1"
  python3 upload.py "${video_file}"
}

update_token_secret() {
  declare channel_code="$1"
  cat token.json | gcloud secrets versions add "${channel_code}_token_json" --data-file=-
}

delete_instance() {
  echo "Deleting instance"
  local instance_name
  instance_name=$(hostname)
  gcloud compute instances delete "${instance_name}" --zone=europe-west1-b --quiet
}


include() {
  declare dir="$1" include_words="$2"
  # Convert the comma-separated list to an array
  IFS=',' read -r -a WORDS <<< "${include_words}"

  # Loop through the directory and include only files with any of the words in the filename
  for file in "$dir"/*; do
    filename=$(basename "$file")
    include=0
    for word in "${WORDS[@]}"; do
      if [[ "$filename" == *"$word"* ]]; then
        include=1
        break
      fi
    done
    if [ "$include" -eq 1 ]; then
      echo "$file"
    fi
  done
}

exclude() {
  declare dir="$1" exclude_words="$2"
  # Convert the comma-separated list to an array
  IFS=',' read -r -a WORDS <<< "$exclude_words"

  # Loop through the directory and exclude files with any of the words in the filename
  for file in "$dir"/*; do
    skip=0
    for word in "${WORDS[@]}"; do
      if [[ "$file" == *"$word"* ]]; then
        skip=1
        break
      fi
    done
    if [ "$skip" -eq 0 ]; then
      realpath "${file}"
    fi
  done
}

ffmpeg_format() {
  output_file="${1:-file_list.txt}"  # Output file, default is 'file_list.txt'

  # Clear the output file if it already exists
  echo "" > "$output_file"

  # Read from stdin (piped input) and write to the FFmpeg list
  while read -r file; do
    echo "file '$file'" >> "$output_file"
  done

  echo "FFmpeg file list saved to $output_file"
}

send_notification() {
  declare subject="${1:-Upload succeeded}" message="${2:-Upload succeeded without errors}"
  echo -e "Subject: ${subject}\n\n${message}" | ssmtp patsysgarden.cattv@gmail.com
}

prepare_for_render() {
  declare project_id="$1"
  download_project_files "${project_id}"
  create_file_list "${project_id}" none
  cp "${project_id}/loop.mov" "${project_id}-loop.mov"
}

time_elapsed_since() {
  declare start_time="$1"
  local end_time
  local elapsed_time
  local minutes
  local seconds
  # Capture the end time
  end_time=$(date +%s)

  # Calculate the elapsed time in seconds
  elapsed_time=$((end_time - start_time))

  # Convert elapsed time to minutes and seconds
  minutes=$((elapsed_time / 60))
  seconds=$((elapsed_time % 60))

  printf "%d minutes and %d seconds" "${minutes}" "${seconds}"
}

copy_loop_portion() {
  declare project_id="$1"
  cp "${project_id}/loop.mov" "${project_id}-loop.mov"
}

main() {
  declare search_term="$1" channel_code="${2:-pg}" intro_file="${3:-intro.mov}" duration="${4:-11:54:59.92}"
  echo "Received args: search_term=${search_term} channel_code=${channel_code} intro_file=${intro_file} duration=${duration}" > /tmp/start_log

  # capture start time
  local start_time
  start_time=$(date +%s)

  {
    # prepare everything
    echo "Installing dependencies" >> /tmp/start_log
    install_dependencies

    echo "Preparing upload script" >> /tmp/start_log
    prepare_upload_script "${channel_code}"

    # search for project
    echo "Finding project" >> /tmp/start_log
    local search_results
    search_results=$(gsls "${search_term}")

    # find project id
    local project_id
    project_id=$(get_id "${search_results}")

    # download the project from google cloud storage
    echo "Downloading project files" >> /tmp/start_log
    gcloud storage cp -r "gs://runloop-videos/${project_id}" ./

    # create the file list used for rendering the looped video
    echo "Creating file list" >> /tmp/start_log
    create_file_list "${project_id}" "${intro_path}"

    # notify of config success
    echo "Sending notification" >> /tmp/start_log
    local elapsed
    elapsed=$(time_elapsed_since "$start_time")
    send_notification "Configuration Success" "Configuration took ${elapsed}. Starting render."

    # stream the 10-hour version of the video
    echo "Rendering video" >> /tmp/start_log
    render_full_video "${project_id}" "${duration}"

    # copy loop portion for upload with meaningful name
    echo "Copying loop portion for upload" >> /tmp/start_log
    copy_loop_portion "${project_id}"

    # upload videos
    echo "Uploading full length video" >> /tmp/start_log
    upload_video "${project_id}.mov" "${channel_code}"
    echo "Uploading loop video" >> /tmp/start_log
    upload_video "${project_id}-loop.mov" "${channel_code}"

    # cleanup
    rm token.json metadata.json

    # notify of success
    echo "Ending" >> /tmp/start_log
    elapsed=$(time_elapsed_since "$start_time")
  } > /tmp/output_log 2>/tmp/error_log

  local output
  output=$(cat /tmp/output_log)
  send_notification "Upload successful" "Script completed in ${elapsed}\n\n${output}"

  echo "Deleting instance" >> /tmp/start_log
  delete_instance
}

error_handler() {
  declare error_message="$1"
  echo "${error_message}"
  send_notification "Stream failed" "${error_message}"
  delete_instance
}