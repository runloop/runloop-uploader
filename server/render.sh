#!/usr/bin/env bash

set -eo pipefail

# download functions from Google Cloud
gcloud storage cp gs://runloop-videos/000-stream-assets/scripts/render-functions.sh ./

# source the functions so they are available in this script
source render-functions.sh

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