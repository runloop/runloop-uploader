#!/usr/bin/env bash

set -eo pipefail

readonly STREAM_KEY=$(curl -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/attributes/stream_key)
sudo sh -c "echo 'STREAM_KEY=${STREAM_KEY}' >> /etc/environment"


gsutil cp "gs://runloop-videos/000-stream-assets/scripts/render-functions.sh" /usr/local/render-functions.sh
sudo chmod -R 755 /usr/local/render-functions.sh
echo "source /usr/local/render-functions.sh" >> /etc/bash.bashrc

sudo apt update
sudo apt install -y screen
sudo apt install -y ffmpeg

