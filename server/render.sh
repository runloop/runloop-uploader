#!/usr/bin/env bash

set -eo pipefail

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
  gsutil cp "gs://runloop-videos/000-stream-assets/scripts/upload.py" .
  # download the correct metadata file (pg/hh)
  gsutil cp "gs://runloop-videos/000-stream-assets/scripts/${channel_code}-metadata.json" "./metadata.json"
  # download the client-secret.json file for the runloop-uploader app
  gcloud secrets versions access latest --secret=client_secret_json > client-secret.json
  # download the secret if it exists
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

  gcloud storage cp -r "gs://runloop-videos/${search_term}" ./
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
  declare path="$1" intro="${2:-intro.mov}" loop="${3:-loop.mov}"

  # Check if the repeat file exists
  if ! check_file_exists "${loop}"; then
    echo "Error: ${loop} does not exist" >&2
    return 0
  fi

  # Repeated value
  local loop_value="file '${loop}'"

  # Create the list
  {
    if check_file_exists "${intro}"; then
      echo "file '${intro}'"
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

render_full_video() {
  echo "Starting render"
  declare file_list="$1" project_id="$2" duration="${3:-9:59:59.92}"
  ffmpeg -y -f concat -safe 0 -i "${file_list}" -c copy -t "${duration}" "${project_id}.mov"
  local ffmpeg_status
  ffmpeg_status=$?
  if [ $ffmpeg_status -ne 0 ]; then
    return 1
  fi
}

upload_video() {
  declare video_file="$1" channel_code="$2"
  echo "Uploaded file: ${video_file}, to channel: ${channel_code}"
  # use the python script to upload the video file
  python3 upload.py "${video_file}"
  # update to the token_json secret
  cat token.json | gcloud secrets versions add "${channel_code}_token_json" --data-file=-
}

delete_instance() {
  echo "Deleting instance"
  local instance_name
  instance_name=$(hostname)
  gcloud compute instances delete "${instance_name}" --zone=europe-west1-b --quiet
}

send_notification() {
  declare subject="${1:-Upload succeeded}" message="${2:-Upload succeeded without errors}"
  echo -e "Subject: ${subject}\n\n${message}" | ssmtp patsysgarden.cattv@gmail.com
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

main() {
  declare search_term="$1" channel_code="${2:-pg}" intro_file="${3:-intro.mov}" duration="${4:-10:00:00.00}"
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
    local file_list="files.txt"
    local intro_path
    local loop_path
    intro_path=$(realpath "${project_id}/${intro_file}")
    loop_path=$(realpath "${project_id}/loop.mov")
    create_file_list "${file_list}" "${intro_path}" "${loop_path}"

    # notify of config success
    echo "Sending notification" >> /tmp/start_log
    local elapsed
    elapsed=$(time_elapsed_since "$start_time")
    send_notification "Configuration Success" "Configuration took ${elapsed}. Starting render."

    # stream the 10-hour version of the video
    echo "Rendering video" >> /tmp/start_log
    render_full_video "${file_list}" "${project_id}" "${duration}"

    # copy loop portion for upload with meaningful name
    echo "Copying loop portion for upload" >> /tmp/start_log
    cp "${project_id}/loop.mov" "${project_id}-loop.mov"

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

trap 'error_handler "$(cat /tmp/error_log)"' ERR

readonly PROJECT=$(curl -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/attributes/project)
readonly INTRO_FILE=$(curl -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/attributes/intro_file)
readonly DURATION=$(curl -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/attributes/duration)
readonly CHANNEL_CODE=$(curl -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/attributes/channel_code)
# TODO: Options to prevent upload and instance deletion

main "$PROJECT" "$CHANNEL_CODE" "$INTRO_FILE" "$DURATION" 2>/tmp/error_log
main_exit_status=$?

if [ $main_exit_status -ne 0 ]; then
  error_handler "$(cat /tmp/error_log)"
  exit $main_exit_status
fi