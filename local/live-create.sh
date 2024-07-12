#!/usr/bin/env bash

set -eo pipefail

SCRIPT_DIR=$(dirname "$(realpath "$0")")

show_help() {
  echo "Usage: live-create.sh <instance-name> [size]"
  echo "Options:"
  echo "  <instance-name>    The name of the instance (required)"
  echo "  [size]             The size of the disk (optional, defaults to 40)"
}

main() {
  declare name="$1" size="${2:-40}"

  echo "Creating instance '${name}' with arguments size='${size}'"

  # copy the latest file to the bucket
  gcloud storage cp "${SCRIPT_DIR}/../server/live-startup.sh" gs://runloop-videos/000-stream-assets/scripts/live-startup.sh

  gcloud compute instances create "${name}" \
    --project=runloop-videos  \
    --zone=europe-west1-b \
    --machine-type=e2-micro \
    --network-interface=network-tier=PREMIUM,stack-type=IPV4_ONLY,subnet=default \
    --maintenance-policy=MIGRATE \
    --provisioning-model=STANDARD \
    --service-account=532820380441-compute@developer.gserviceaccount.com \
    --scopes=https://www.googleapis.com/auth/devstorage.read_only,https://www.googleapis.com/auth/logging.write,https://www.googleapis.com/auth/monitoring.write,https://www.googleapis.com/auth/servicecontrol,https://www.googleapis.com/auth/service.management.readonly,https://www.googleapis.com/auth/trace.append \
    --create-disk=auto-delete=yes,boot=yes,device-name=stream-template,image=projects/ubuntu-os-cloud/global/images/ubuntu-2004-focal-v20240607,mode=rw,size=40,type=projects/runloop-videos/zones/europe-west1-b/diskTypes/pd-standard \
    --no-shielded-secure-boot \
    --shielded-vtpm \
    --shielded-integrity-monitoring \
    --labels=goog-ec-src=vm_add-gcloud \
    --reservation-affinity=any \
    --metadata="startup-script-url=gs://runloop-videos/000-stream-assets/scripts/live-startup.sh"
}

# Check if the first argument is provided
if [ -z "$1" ]; then
  echo "Error: The first argument is required and should be a string containing letters, numbers, or dashes."
  show_help
  exit 1
fi

# Check if the first argument is a valid string (letters, numbers, and dashes)
if [[ ! "$1" =~ ^[a-zA-Z0-9-]+$ ]]; then
  echo "Error: The first argument should only contain letters, numbers, or dashes."
  show_help
  exit 1
fi

# Check if the second argument is provided and is a number
if [ -n "$2" ] && [[ ! "$2" =~ ^[0-9]+$ ]]; then
  echo "Error: The second argument should be a number."
  show_help
  exit 1
fi

main "$@"