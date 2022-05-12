#!/bin/sh

set YT_URL='https://www.youtube.com/playlist?list='
set PLAYLIST_ID='PLVAh-MgDVqvDUEq6qDXqORBioE4Yhol_z'

function apk_update {
  apk update
}

function apk_upgrade {
  apk upgrade
}

function install_ffmpeg {
  apk add ffmpeg
}

function install_youtube_dl {
  apk add youtube-dl
}

function build_index_file {
  # If a media index already exists...
  if [ -f "/media_index" ]; then
    # If an old index already exists...
    if [ -f "/media_index_old" ]; then
      # Forcefully remove the previous old index.
      rm -f /media_index_old
    fi

    # Rename previous index as an old index.
    mv /media_index /media_index_old
  fi

  # Build a new index file based on current data.
  youtube-dl \
    --simulate \
    --yes-playlist \
    --flat-playlist \
    --get-id \
    --get-title
    "${YT_URL}${PLAYLIST_ID}" > /tmp_index

  local titles=
  local title_count=0

  local ids=
  local id_count=0

  local line_num=1

  # Parse raw contents of media index file.
  while IFS= read LINE in /tmp_index; do
    if [ $(( $line_num % 2 )) -eq 1 ]; then
      # We are reading a media title.
      #
      # Formatting rules:
      #
      # The title must be a lower-case string.
      # The title must not contain redundant information.
      # The title must not contain characters forbidden in filenames.
      # The title must be in kebab-case form with only hypthens.
      # The title must not contain two or more hyphens strung together.
      tmp_title="$( \
        echo "${LINE}" | \
        tr '[:upper:]' '[:lower:]' | \
        sed '
        s|[^\ ]\{0,\}[\ ]\{0,\}[backroms]\{9\}[\ -]\{1,3\}\(.*\)|\1|;
        s|[()]||g;
        s|[\_\.\ ]|-|g;
        s|[-]\{2,\}|-|g;
        ' \
      )"

      # Append the formatted media title.
      titles="${titles} ${tmp_title}"
      title_count=$(( $title_count + 1 ))

    elif [ $(( $line_num % 2 )) -eq 0 ]; then
      # We are reading a media id.
      
      # Append the media id as-is.
      ids="${ids} ${LINE}"
      id_count=$(( $id_count + 1 ))

    fi

    # Increment the line number.
    line_num=$(( $line_num + 1 ))
  done

  # If the word counts of `titles` and `ids` mismatch, something wen't wrong.
  if [ $title_count -ne $id_count ]; then
    echo "ERROR: mismatch found between titles and ids of requested media."
    return 1
  fi

  # Erase the improperly formatted media index.
  rm -f /tmp_index

  for i in {1..$id_count}; do
    # Extract the ith id.
    local tmp_i=$( echo "${ids}" | cut -d ' ' -f $i )

    # Extract the ith title.
    local tmp_t=$( echo "${titles}" | cut -d ' ' -f $i )

    # Append the concatenated data to the new reformatted media index.
    echo "${tmp_i} ${tmp_t}" >> /media_index
  done
}

function download_and_process_media {
  # If the media index doesn't exist then a filesystem error has occurred.
  if [ ! -f /media_index ]; then
    echo "ERROR: Media index file not found."
    return 1
  fi

  # Iterate over the lines of data in our index file.
  for l in {1..$( wc -l < /media_index )}; do

    # Extract the line of current data given by line number `l`.
    local index_data="$( awk 'NR=='${l}'{ print; exit; }' /media_index )"

    # If an older index also exists for diffing...
    if [ -f /media_index_old ]; then

      # And if the line count of `l` is in the range of the older index...
      if [ $(( $( wc -l < /media_index_old ) - $l )) -ge 0 ]; then

        # Extract the line of old data given by linecount `l`.
        local old_data="$( awk 'NR=='${l}'{ print; exit; }' /media_index_old )"

        # If the current and older data match...
        if [ "${index_data}" = "${old_data}" ]; then

          # Go to the next iteration of the loop.
          continue
        fi
      fi
    fi

    local media_title=
    local media_id=

    # Extract the media title.
    media_title="$( echo "${index_data}" | cut -d ' ' -f 2 )"

    # Extract the media id.
    media_id="$( echo "${index_data}" | cut -d ' ' -f 1 )"

    # Prepare a video destination folder for the webm.
    mkdir -pm 0755 /research/${media_title}/video

    # Download a temporary webm with no sound.
    youtube-dl \
      --format 271 \
      --output /research/${media_title}/video/${media_title}-temp.webm
      https://www.youtube.com/watch?v=${media_id}

    # Prepare a audio destination folder for the opus.
    mkdir -m 0755 /research/${media_title}/audio
    
    # Download the audio in opus format.
    youtube-dl \
      --format 22 \
      -x --audio-format opus \
      --audio-quality 0 \
      --output /research/${media_title}/audio/${media_title}.opus \
      https://www.youtube.com/watch?v=${media_id}

    # Combine video and audio files.
    ffmpeg \
      -i /research/${media_title}/video/${media_title}-temp.webm \
      -i /research/${media_title}/audio/${media_title}.opus \
      -c:v copy -c:a libopus -b:a 128k \
      /research/${media_title}/video/${media_title}.webm

    # Delete temporary "no sound" video file.
    rm -f /research/${media_title}/video/${media_title}-temp.webm

    # Create a folder for exported frames.
    mkdir -m 0755 /research/${media_title}/frames

    # Extract the frames of the current video.
    ffmpeg \
      -i /research${media_title}/video/${media_title}.webm \
      -vf scale=320:240,setsar=1:1 \
      /research/${media_title}/frames/${media_title}-%08d.png
  done
}

function install {
  # Call all of our functions, contingent upon the previous success code.
  apk_update
  [ $? -eq 0 ] && apk_upgrade
  [ $? -eq 0 ] && install_ffmpeg
  [ $? -eq 0 ] && install_youtube_dl
  [ $? -eq 0 ] && build_index_file
  [ $? -eq 0 ] && download_and_process_media
}