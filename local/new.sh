#!/usr/bin/env bash

set -eo pipefail

SCRIPT_DIR=$(dirname "$(realpath "$0")")

show_help() {
  echo "Usage: new.sh [options]"
  echo "Options:"
  echo "  -n <name>          The instance name"
  echo "  -k <stream-key>    The stream key (required)"
  echo "  -d <disk-type>     The type of disk (optional, valid options (standard, balanced, ssd), defaults to standard)"
  echo "  -c <capacity>      The size of the disk (optional, defaults to 25)"
  echo "  -t <type>          The type of instance (optional, valid options (e2-micro, e2-small, e2-medium), defaults to e2-micro)"
  echo "  -h                 Show this help message"
}

# Default values
NAME=""
STREAM_KEY=""
DISK="standard"
CAPACITY="10"
TYPE="e2-micro"

while getopts ":n:k:d:c:t:h" opt; do
  case ${opt} in
    n )
      NAME=$OPTARG
      ;;
    k )
      STREAM_KEY=$OPTARG
      ;;
    d )
      DISK=$OPTARG
      ;;
    c )
      CAPACITY=$OPTARG
      ;;
    t )
      TYPE=$OPTARG
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

# Check if name is provided
if [ -z "${NAME}" ]; then
  echo "Error: Server name -n is required and should be a string containing letters, numbers, or dashes."
  show_help
  exit 1
fi

# Check if name is a valid string (letters, numbers, and dashes)
if [[ ! "${NAME}" =~ ^[a-zA-Z0-9-]+$ ]]; then
  echo "Error: Server name -n should only contain letters, numbers, or dashes."
  show_help
  exit 1
fi

# Check if capacity is provided and is a number
if [ -n "${CAPACITY}" ] && [[ ! "${CAPACITY}" =~ ^[0-9]+$ ]]; then
  echo "Error: capacity -c should be a number."
  show_help
  exit 1
fi

if [ -n "$DISK" ] && [[ "$DISK" != "standard" && "$DISK" != "balanced" && "$DISK" != "ssd" ]]; then
  echo "Error: disk -d must be set to either 'standard', 'balanced', or 'ssd'."
  show_help
  exit 1
fi

if [ -n "${TYPE}" ] && [[ "${TYPE}" != "e2-micro" && "${TYPE}" != "e2-small" && "${TYPE}" != "e2-medium" ]]; then
  echo "Error: disk -d must be set to either 'e2-micro', 'e2-small', or 'e2-medium'."
  show_help
  exit 1
fi

if [[ ! "$STREAM_KEY" =~ ^[a-z0-9]{4}(-[a-z0-9]{4}){4}$ ]]; then
  echo "Error: stream key -k is not in a valid YouTube stream key format."
  show_help
  exit 1
fi

echo "Provisioning new '${TYPE}' instance named '${NAME}' with a ${CAPACITY}gb ${DISK} disk for stream key '${STREAM_KEY}'."

# copy the latest file to the bucket
gcloud storage cp "${SCRIPT_DIR}/../server/boot.sh" gs://runloop-videos/000-stream-assets/scripts/boot.sh

# disk types: pd-standard, pd-ssd, pd-balanced,
gcloud compute instances create "${NAME}" \
  --project=runloop-videos  \
  --zone=europe-west1-b \
  --machine-type="${TYPE}" \
  --network-interface=network-tier=PREMIUM,stack-type=IPV4_ONLY,subnet=default \
  --maintenance-policy=MIGRATE \
  --provisioning-model=STANDARD \
  --service-account=532820380441-compute@developer.gserviceaccount.com \
  --scopes=https://www.googleapis.com/auth/devstorage.read_only,https://www.googleapis.com/auth/logging.write,https://www.googleapis.com/auth/monitoring.write,https://www.googleapis.com/auth/servicecontrol,https://www.googleapis.com/auth/service.management.readonly,https://www.googleapis.com/auth/trace.append \
  --create-disk=auto-delete=yes,boot=yes,device-name=stream-template,image=projects/ubuntu-os-cloud/global/images/ubuntu-2004-focal-v20240830,mode=rw,size="${CAPACITY}",type=projects/runloop-videos/zones/europe-west1-b/diskTypes/pd-"${DISK}" \
  --no-shielded-secure-boot \
  --shielded-vtpm \
  --shielded-integrity-monitoring \
  --labels=goog-ec-src=vm_add-gcloud \
  --reservation-affinity=any \
  --metadata="startup-script-url=gs://runloop-videos/000-stream-assets/scripts/boot.sh,stream_key=${STREAM_KEY}"