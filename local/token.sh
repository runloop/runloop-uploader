#!/usr/bin/env bash

set -eo pipefail

SCRIPT_DIR=$(dirname "$(realpath "$0")")
echo $SCRIPT_DIR

show_help() {
  echo "Usage: token.sh [options]"
  echo "Options:"
  echo "  -c <channel-code>  The channel code to upload to (optional, valid options are pg/hh/ko, default to pg)"
  echo "  -h                 Show this help message"
}

# Default values
CHANNEL_CODE=""

while getopts ":c:h" opt; do
  case ${opt} in
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

# Check if -c was provided
if [ -z "${CHANNEL_CODE}" ]; then
  echo "You must provide a stream key using the option -c"
  show_help
  exit 1
fi

refresh_token() {
  python3 "${SCRIPT_DIR}/../refresh-token.py"
}

update_token_secret() {
  declare channel_code="$1"
  cat "${SCRIPT_DIR}/../token.json" | gcloud secrets versions add "${channel_code}_token_json" --data-file=-
}

main() {
  declare channel_code="$1"
  refresh_token
  update_token_secret "${channel_code}"
}

main "${CHANNEL_CODE}"