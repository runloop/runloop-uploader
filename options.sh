#!/usr/bin/env bash

set -eo pipefail

show_help() {
  echo "Usage: upload.sh [options]"
  echo "Options:"
  echo "  -q [query]         The query to search for in project titles"
  echo "  -i [filename]      The name of the intro file (defaults to intro.mov)"
  echo "  -d [timecode]      The designed duration (defaults to 9:59:59.92)"
  echo "  -c [code]          Set the channel code (defaults to pg, allowed values: pg,hh)"
  echo "  -h                 Show this help message"
}

# Default values
QUERY=""
INTRO_FILE="intro.mov"
DURATION="9:59:59.92"
CHANNEL_CODE="pg"

# Parse the remaining options using getopts
while getopts ":q:i:d:c:h" opt; do
  case ${opt} in
    q )
      QUERY=$OPTARG
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
    c )
      case $OPTARG in
        pg|hh)
          CHANNEL_CODE=$OPTARG
          ;;
        *)
          echo "Invalid value for -c. Allowed values are: pg, hh."
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
shift $((OPTIND -1))

# Check if -q or --query was provided
if [ -z "$QUERY" ]; then
  echo "The -q argument is required."
  show_help
  exit 1
fi

# Debug output to verify variables
echo "CHANNEL: ${CHANNEL_CODE}"
echo "DURATION: ${DURATION}"
echo "QUERY: ${QUERY}"
echo "INTRO_FILE: ${INTRO_FILE}"