alias be='nano ~/.bashrc && source ~/.bashrc'
alias ss="screen -S"
alias sr="screen -r"
alias sls="screen -ls"

skill() {
  screen -S $1 -X quit
}

find_project() {
  if [ $# -lt 1 ] || [ $# -gt 2 ]; then
    echo "Usage: find_project <project-id> [filename]"
    return 1
  fi

  local bucket_name=runloop-videos
  local search_string=$1
  local filename=$2

  if [ -z "${filename}" ]; then
    filename=loop.mov
  fi

  # List directories in the bucket and filter by the search string
  local results
  results=$(gsutil ls -d "gs://${bucket_name}/*/${filename}" | grep "${search_string}")

  if [ -z $results ]; then
    echo "Error: Expected 1 result, but found 0"
    return 1
  fi

  # Count the number of results
  local count
  count=$(echo "${results}" | wc -l)

  if [ "${count}" -eq 1 ]; then
    echo "${results}"
  else
    echo "Error: Expected 1 result, but found ${count}:"
    echo "${results}"
    return 1
  fi
}

ffmpeg_hls() {
  if [ $# -ne 2 ]; then
    echo "Usage: ffmpeg-hls <stream-key> <path>"
    return 1
  fi

  local stream_key=$1
  local path=$2

  ffmpeg -re -stream_loop -1 -i $path -c copy -bufsize 10000k -method POST -f hls -ignore_io_errors 1 "https://a.upload.youtube.com/http_upload_hls?cid=$stream_key&copy=0&file=index.m3u8"
}

stream() {
  # check we have the correct number of params
  if [ $# -lt 3 ] || [ $# -gt 4 ]; then
    echo "Usage: stream <stream-id> <stream-key> <project-id> [filename]"
    return 1
  fi

  # define local variables
  local stream_id=$1
  local stream_key=$2
  local project_id=$3
  local filename=$4

  # kill any screen currently attached
  screen -S "${stream_id}" -p 0 -X quit

  # find the cloud file name based on the project id
  local cloud_file=$(find_project $3 $4)
  if [ $? -ne 0 ]; then
    echo "Failed to find project"
    return 1
  fi

  # create a directory for the stream_id
  mkdir -p ~/$stream_id

  # create a local path
  local local_file=~/$stream_id/stream.mov

  #download the cloud file to the stream_id dir
  gcloud storage cp $cloud_file $local_file

  # start a detached screen session and start ffmpeg
  screen -dmS "${stream_id}" ffmpeg -re -stream_loop -1 -i $local_file -c copy -bufsize 10000k -method POST -f hls -ignore_io_errors 1 "https://a.upload.youtube.com/http_upload_hls?cid=$stream_key&copy=0&file=index.m3u8"
}

init() {
  if [ $# -ne 2 ]; then
    echo "Usage: init <stream-id> <stream-key>"
    return 1
  fi

  local stream_id=$1
  local stream_key=$2

  cat <<EOL >> ~/.bashrc
alias $stream_id='stream $stream_id $stream_key'
alias _$stream_id='screen -dmS "${stream_id}" ffmpeg -re -stream_loop -1 -i $stream_id/stream.mov -c copy -bufsize 10000k -method POST -f hls -ignore_io_errors 1 "https://a.upload.youtube.com/http_upload_hls?cid=$stream_key&copy=0&file=index.m3u8"'
EOL
  source ~/.bashrc
}

cat <<EOF
Welcome to the streaming server. The following commands are available to you:

Screens:
ss        - Start a new screen session that will persist after exiting this ssh session
sr        - Reattach to the existing screen session
ctrl+a, d - exit a screen

Streaming:
init <stream-id> <stream-key> - Creates a new alias called <stream-id> which can used as follows:
<stream-id> <project-id> [filename] - start a stream for the <project-id>. This will default to loop.mov
EOF



alias pg7='stream pg7 99rt-zj9x-2res-pb4v-2sc6'
alias _pg7='screen -dmS "pg7" ffmpeg -re -stream_loop -1 -i pg7/stream.mov -c copy -bufsize 10000k -method POST -f hls -ignore_io_errors 1 "https://a.upload.youtube.com/http_upload_hls?cid=99rt-zj9x-2res-pb4v-2sc6&copy=0&file=index.m3u8"'
alias pg8='stream pg8 9f7k-7226-th2r-pwum-cxka'
alias _pg8='screen -dmS "pg8" ffmpeg -re -stream_loop -1 -i pg8/stream.mov -c copy -bufsize 10000k -method POST -f hls -ignore_io_errors 1 "https://a.upload.youtube.com/http_upload_hls?cid=9f7k-7226-th2r-pwum-cxka&copy=0&file=index.m3u8"'


stream_id="pg1"
search_term="111.1"
sfx_url="gs://..."
music_url="gs://..."
# kill any screen that is attached with the id

# delete stream directory matching the stream id

# download the project for the search_term

# start a detached screen session and start ffmpeg