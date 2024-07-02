#!/usr/bin/env bash

set -eo pipefail

prepare_upload_script() {
  declare channel_code="$1"
  echo "Preparing upload script for ${channel_code}"
  # download the python script for uploading
  gsutil cp "gs://runloop-videos/000-stream-assets/scripts/upload.py" .
  # download the correct metadata file (pg/hh)
  gsutil cp "gs://runloop-videos/000-stream-assets/scripts/${channel_code}-metadata.json" "./metadata.json"
  # download the client-secret.json file for the runloop-uploader app
  gcloud secrets versions access latest --secret=client_secret_json > client-secret.json

  local secret_name="${channel_code}_token_json"

  # check that the secret exists before attempting to download
  if gcloud secrets describe "${secret_name}" --quiet ; then
    # Access the latest version of the secret and write it to token.json
    gcloud secrets versions access latest --secret="${secret_name}" > token.json
  fi
}

upload_video() {
  declare channel_code="$1" video_file="$2"
  echo "Uploading file: ${video_file}, to channel: ${channel_code}"
  # use the python script to upload the video file
  python3 upload.py "${video_file}"
  # update to the token_json secret
  cat token.json | gcloud secrets versions add "${channel_code}_token_json" --data-file=-
  rm token.json metadata.json
}

main() {
  declare channel_code="$1" video_file="$2"
  prepare_upload_script "${channel_code}"
  upload_video "${channel_code}" "${video_file}"
}

main "$@"