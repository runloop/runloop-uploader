#!/usr/bin/env bash

set -eo pipefail

sudo apt update
sudo apt install -y screen
sudo apt install -y ffmpeg