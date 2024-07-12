#!/usr/bin/env bash

set -eo pipefail

SCRIPT_DIR=$(dirname "$(realpath "$0")")

show_help() {
  echo "Usage: render.sh [options]"
  echo "Options:"
  echo "  -p <project>       The query used to locate the project (required)"
  echo "  -c <channel-code>  The channel code to upload to (optional, valid options are pg/hh/ko, default to pg)"
  echo "  -i <intro-file>    The name of the intro file (optional, defaults to intro.mov)"
  echo "  -d <duration>      The length of the rendered file (optional, defaults to 9:59:59.92)"
  echo "  -h                 Show this help message"
}

# Default values
QUERY=""
CHANNEL_CODE="pg"
INTRO_FILE="intro.mov"
DURATION="9:59:59.92"

while getopts ":p:c:i:d:h" opt; do
  case ${opt} in
    p )
      QUERY=$OPTARG
      ;;
    c )
      case $OPTARG in
        pg|hh|ko)
          CHANNEL_CODE=$OPTARG
          ;;
        *)
          echo "Invalid value for -c. Allowed values are: pg, hh, ko."
          show_help
          exit 1
          ;;
      esac
      ;;
    i )
      INTRO_FILE=$OPTARG
      ;;
    d )
      if [[ "$OPTARG" =~ ^((((([0-5][0-9]|[0-9])\:)?[0-5][0-9]|[0-9])\:)?[0-5][0-9]|[0-9])(\.[0-9]{2})?$ ]]; then
        DURATION=$OPTARG
      else
        echo "Invalid value for -d. Must be of format [HH:][MM:]SS[.cc]"
        show_help
        exit 1
      fi
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
if [ -z "${QUERY}" ]; then
  echo "You must provide a project query using the option -p"
  show_help
  exit 1
fi

# Check if -k was provided
if [ -z "${CHANNEL_CODE}" ]; then
  echo "You must provide a stream key using the option -k"
  show_help
  exit 1
fi

main() {
  declare channel_code="$1" project="$2" intro_file="$3" duration="$4"
  local project_id
  project_id=$(echo "${project}" | sed -E 's/[^a-zA-Z0-9]+/-/g')
  echo "Creating instance 'render-${project_id}' with arguments project='${project}' channel_code='${channel_code}' intro_file='${intro_file}' duration='${duration}'"

  # copy the latest file to the bucket
  gcloud storage cp "${SCRIPT_DIR}/../server/render.sh" gs://runloop-videos/000-stream-assets/scripts/render.sh

  # create the new instance which will run the script
  gcloud compute instances create "render-${project_id}" \
    --project=runloop-videos \
    --zone=europe-west1-b \
    --machine-type=e2-micro \
    --network-interface=network-tier=PREMIUM,stack-type=IPV4_ONLY,subnet=default \
    --maintenance-policy=MIGRATE \
    --provisioning-model=STANDARD \
    --service-account=532820380441-compute@developer.gserviceaccount.com \
    --scopes=https://www.googleapis.com/auth/cloud-platform,https://www.googleapis.com/auth/compute,https://www.googleapis.com/auth/servicecontrol,https://www.googleapis.com/auth/service.management.readonly,https://www.googleapis.com/auth/logging.write,https://www.googleapis.com/auth/monitoring.write,https://www.googleapis.com/auth/trace.append,https://www.googleapis.com/auth/devstorage.read_only \
    --create-disk=auto-delete=yes,boot=yes,device-name=stream-template,image=projects/ubuntu-os-cloud/global/images/ubuntu-2004-focal-v20240607,mode=rw,size=250,type=projects/runloop-videos/zones/europe-west1-b/diskTypes/pd-ssd \
    --no-shielded-secure-boot \
    --shielded-vtpm \
    --shielded-integrity-monitoring \
    --labels=goog-ec-src=vm_add-gcloud \
    --reservation-affinity=any \
    --metadata="startup-script-url=gs://runloop-videos/000-stream-assets/scripts/render.sh,project=${project},intro_file=${intro_file},duration=${duration},channel_code=${channel_code}"
}

main "${CHANNEL_CODE}" "${QUERY}" "${INTRO_FILE}" "${DURATION}"