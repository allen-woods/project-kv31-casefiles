#!/bin/sh

export YT_URL=https://www.youtube.com/playlist\?list\=
export PLAYLIST_ID=PLVAh-MgDVqvDUEq6qDXqORBioE4Yhol\_z

function apk_update {
  echo "Updating package repositories..." | tr -d '\n'
  apk update 2>&1 >/dev/null
  if [ $? -gt 0 ]; then
    echo -e "\033[0;31mFAILED\033[0m"
    return 1
  fi
  echo -e "\033[1;32mSUCCESS\033[0m"
}

function apk_upgrade {
  echo "Upgrading package versions..." | tr -d '\n'
  apk upgrade 2>&1 >/dev/null
  if [ $? -gt 0 ]; then
    echo -e "\033[0;31mFAILED\033[0m"
    return 1
  fi
  echo -e "\033[1;32mSUCCESS\033[0m"
}

function install_python {
  echo "Installing python..." | tr -d '\n'
  apk add python3 2>&1 >/dev/null
  ln -s /usr/bin/python3 /usr/bin/python
}

function verify_python_install {
  if [ \
    "$( python --version | cut -d ' ' -f 1 )" != "Python" \
  ]; then
    echo -e "\033[0;31mFAILED\033[0m"
    return 1
  fi
  echo -e "\033[1;32mSUCCESS\033[0m"
}

function install_ffmpeg {
  echo "Installing ffmpeg..." | tr -d '\n'
  apk add ffmpeg 2>&1 >/dev/null
}

function verify_ffmpeg_install {
  if [ \
    "$( ffmpeg 2>&1 | tr -d '\n' | awk '{ print $1 }' )" != "ffmpeg" \
  ]; then
    echo -e "\033[0;31mFAILED\033[0m"
    return 1
  fi
  echo -e "\033[1;32mSUCCESS\033[0m"
}

function install_youtube_dl {
  echo "Installing youtube-dl..." | tr -d '\n'
  # Download over wget.
  wget \
    -cq \
    -O /usr/bin/youtube-dl \
    https://yt-dl.org/downloads/latest/youtube-dl

  # Alias and give executable permissions to binary.
  chmod a+rx /usr/bin/youtube-dl
}

function verify_youtube_dl_install {
  if [ \
    "$( youtube-dl 2>&1 | tr -d '\n' | awk '{ print $2 }' )" != "youtube-dl" \
  ]; then
    echo -e "\033[0;31mFAILED\033[0m"
    return 1
  fi
  echo -e "\033[1;32mSUCCESS\033[0m"
}

function build_index_file {
  # If no arguments have been passed in...
  if [ -z "${1}" ] || [ -z "${2}" ]; then
    # Print user feedback to the terminal.
    echo "ERROR: You must pass output file and media format as arguments."
    echo "usage: ${0} <video|audio> <271|22>"
    # ...We can go no further.
    return 1
  fi

  # If a previous media index file exists, erase it.
  [ -f "${1}_index" ] && rm -f "${1}_index"

  echo "Building temporary ${1} index..." | tr -d '\n'

  # Build temporary unformatted media index file.
  youtube-dl \
    --yes-playlist \
    --format $2 \
    --simulate \
    --get-title \
    --get-url \
    "${YT_URL}${PLAYLIST_ID}" > "tmp_${1}_index"

  # If the last command encountered an error or the generated file is empty...
  if [ $? -ne 0 ] || [ -z "$( cat "tmp_${1}_index" )" ]; then
    # Print user feedback to the terminal.
    echo -e "\033[0;31mFAILED\033[0m"
    # ...We can go no further.
    return 1
  fi

  # Variables related to text transformations performed on temporary index file.
  local media_basename=
  local media_url=
  local i=1

  # While we are within the bounds of the temp index file's line count...
  while [ $i -le $( wc -l < "tmp_${1}_index" ) ]; do

    # ...Extract and transform title of media.
    media_basename=$( \
      sed "${i}q;d" < "tmp_${1}_index" | \
      tr '[:upper:]' '[:lower:]' | \
      sed '
      s|[^\ ]\{0,\}[\ ]\{0,\}[backroms]\{9\}[\ -]\{1,3\}\(.*\)|\1|;
      s|[()]||g;
      s|[\_\.\ ]|-|g;
      s|[-]\{2,\}|-|g;
      ' \
    )

    # ...Extract and hard quote url of media.
    media_url="$( sed "$(( $i + 1 ))q;d" < "tmp_${1}_index" )"

    # Only append valid data to the end of destination file.
    # (No blank lines!)
    if [ ! -z "${media_basename}" ] && [ ! -z "${media_url}" ]; then
      echo "${media_basename} ${media_url}" >> "${1}_index"
    fi

    # Increment by 2.
    i=$(( $i + 2 ))
  done

  # Erase the temporary media index.
  rm -f "tmp_${1}_index"
  echo -e "\033[1;32mSUCCESS\033[0m"
}

# Verify media index data
function verify_media_index_integrity {
  echo "Verifying data..." | tr -d '\n'

  # Require both indices to contain the same number of entries.
  if [ $( wc -l < video_index ) -ne $( wc -l < audio_index ) ]; then
    echo -e "\033[0;31mFAILED\033[0m"
    echo "Mismatched item counts between audio and video."
    return 1
  fi

  local i=1
  while [ $i -le $( wc -l < video_index ) ]; do
    video_title=$( sed "${i}q;d" < video_index | cut -d ' ' -f 1 )
    video_url=$( sed "${i}q;d" < video_index | cut -d ' ' -f 2 )

    audio_title=$( sed "${i}q;d" < audio_index | cut -d ' ' -f 1 )
    audio_url=$( sed "${i}q;d" < audio_index | cut -d ' ' -f 2 )

    # Require both indices to contain a common name at index N.
    if [ "${video_title}" != "${audio_title}" ]; then
      echo -e "\033[0;31mFAILED\033[0m"
      echo "Video and audio items ${i} do not share common name."
      return 1
    fi

    # Forbid both indices to share a URL at any given index N.
    if [ "${video_url}" = "${audio_url}" ]; then
      echo -e "\033[0;31mFAILED\033[0m"
      echo "Video and audio items ${i} reference the same URL."
      return 1
    fi

    # Increment through the entries.
    i=$(( $i + 1 ))
  done
  echo -e "\033[1;32mSUCCESS\033[0m"
}

# Prepare folders for all videos and audio tracks not yet downloaded.
function prepare_filesystem {
  echo "Preparing filesystem..." | tr -d '\n'

  # Variables related to parsing media index entries.
  local folder_name=
  local i=1

  # While we are in the bounds of media index's line count...
  while [ $i -le $( wc -l < video_index ) ]; do
    # ...Capture the intended folder name from the current entry.
    folder_name=$( sed "${i}q;d" < video_index | cut -d ' ' -f 1 )

    # If a folder does not exist with that name yet...
    if [ ! -d /research/$folder_name ]; then

      # ...Create the folder.
      mkdir -m 0755 /research/$folder_name
    fi

    # Increment to next line of media index.
    i=$(( $i + 1 ))
  done

  echo -e "\033[1;32mSUCCESS\033[0m"
}

function download_any {
  # Calculate the number of hyperthreads available, minus one.
  local ht_count=$(( $( nproc ) * 2 - 1 ))
  # Store the line count of the media index.
  local l_count=$( wc -l < video_index )
  # Subprocess count, preferring the smaller of ht_count and l_count.
  local p_count=

  # Ternary logic for assigning smallest number of subprocesses to spawn.
  [ $l_count -le $ht_count ] && p_count=$l_count || p_count=$ht_count
  
  local episode=
  local video_url=
  local audio_url=
  local i=1;

  while [ $i -le $l_count ]; do
    episode=$( sed "${i}q;d" < video_index | cut -d ' ' -f 1 )
    video_url=$( sed "${i}q;d" < video_index | cut -d ' ' -f 2 )
    audio_url=$( sed "${i}q;d" < audio_index | cut -d ' ' -f 2 )
    local pretty="$( \
      echo $episode | \
      sed 's|-|\ |g' | \
      awk '{for(j=1;j<=NF;j++){$j=toupper(substr($j,1,1)) substr($j,2)}}1' \
    )"

    # If the video data for this item has not been downloaded...
    if [ ! -d /research/$episode/video ]; then
      
      # ...Create a directory for the file.
      mkdir -m 0755 /research/$episode/video
      
      # Inform user that this process will take a very long time.
      echo -e "\033[1;33m * * * Downloading: Video Data * * *\033[0m"
      echo -e "\033[1;33m *\033[0m"
      echo -e "\033[1;33m * Item: \"${pretty}\"\033[0m"
      echo -e "\033[1;33m *\033[0m"
      echo -e "\033[1;33m * * * * * * * * * * * * * * * * * *\033[0m"

      export EC=1

      while [ $EC -ne 0 ]; do
        # Download the file.
        wget \
          -c \
          -O /research/$episode/video/$episode.webm \
          $video_url
        export EC=$?
        sleep 1m
      done

      # Inform the user the download finished.
      echo -e "\033[1;32mDOWNLOAD COMPLETE\033[0m"
    fi

    # If the audio data for this item has not been downloaded...
    if [ ! -d /research/$episode/audio ]; then
      
      # ...Create a directory for the file.
      mkdir -m 0755 /research/$episode/audio
      
      # Inform user that this process will take a very long time.
      echo -e "\033[1;33m * * * Downloading: Audio Data * * *\033[0m"
      echo -e "\033[1;33m *\033[0m"
      echo -e "\033[1;33m * Item: \"${pretty}\"\033[0m"
      echo -e "\033[1;33m *\033[0m"
      echo -e "\033[1;33m * * * * * * * * * * * * * * * * * *\033[0m"
      
      export EC=1

      while [ $EC -ne 0 ]; do
        # Download the file.
        wget \
          -c \
          -O /research/$episode/audio/$episode.m4a \
          $audio_url
        export EC=$?
        sleep 1m
      done
      
      # Inform the user the download finished.
      echo -e "\033[1;32mDOWNLOAD COMPLETE\033[0m"
    fi

    # Increment to the next item.
    i=$(( $i + 1 ))
  done
}

# Export all frames of each merged video/audio file.
function export_frames {
  for episode in /research/*; do
    # Strip the path from the episode name.
    episode=$( basename $episode )

    # Only export frames that have not yet been exported.
    if [ ! -d /research/$episode/frames ]; then
      echo "Exporting all video frames for '${episode}'."
      mkdir -m 0755 /research/$episode/frames
      ffmpeg \
        -i /research/$episode/video/$episode.webm \
        -vf scale=320:240,setsar=1:1 \
        /research/$episode/frames/$episode-frame-%08d.png
    fi
  done
}

# Post-process each video to contain it's associated audio track.
function combine_video_and_audio {
  for episode in /research/*; do
    # Strip the path from the episode name.
    episode=$( basename $episode )

    # Only combine episodes that have not yet been combined.
    if [ ! -f /research/$episode/$episode-with-sound.webm ]; then
      echo "Combining video and audio for '${episode}'."
      echo -e "\033[0;31m* * * CAUTION: * * *"
      echo -e "- This media post-processing consumes a lot of CPU."
      echo -e "- Running heavy background processes is unadvisable.\033[0m"

      # Run ffmpeg at highest quality.
      ffmpeg \
        -i /research/$episode/video/$episode.webm \
        -i /research/$episode/audio/$episode.m4a \
        -c:v libvpx-vp9 -crf 0 \
        -c:a libopus -q:a 0 -b:a 128k \
        /research/$episode/$episode-with-sound.webm
    fi
  done
}

# Generate entries for use with the obsidian vault provided by /research.
function generate_obsidian_notes {
  # Look through all of the episodes downloaded so far.
  for episode in /research/*; do
    # Strip the path from the episode name.
    episode=$( basename $episode )

    # If a notes directory does not exist...
    if [ ! -d /research/$episode/notes ]; then

      # Print user feedback to the terminal.
      echo "Generating Obsidian Notes for '${episode}'."

      # Create the notes directory for this episode.
      mkdir -m 0755 /research/$episode/notes

      # Variables to track linear time across frames.
      local last_note=
      local this_note=

      # Iterate across the frames exported from this episode.
      for image in /research/$episode/frames/*; do
        # Strip the path from the image name.
        image=$( basename $image )

        # Convert the image name to a headline string.
        this_note="$(
          echo $image | \
          sed 's|^\(.*\)[\.png]\{4\}$|\1|; s|-|\ |g;' | \
          awk '{for(i=1;i<=NF;i++){$i=toupper(substr($i,1,1)) substr($i,2)}}1' \
        )"

        # Print the information regarding this image into its note.
        printf '%s\n' \
        "# ${this_note}" \
        "" \
        "![[../frames/${image}]]" \
        "" > "${this_note}.md"

        # If we have generated at least one note previously...
        if [ ! -z "${last_note}" ]; then

          # And if the two strings are not the same...
          if [ "${last_note}" != "${this_note}" ]; then

            # ...Append a reference to last note on to the end of this note.
            printf '%s\n' \
            "## Prev Frame" \
            "" \
            "[[${last_note}]]" \
            "" >> "${this_note}.md"

            # ...Append a reference to this note on to the end of last note.
            printf '%s\n' \
            "## Next Frame" \
            "" \
            "[[${this_note}]]" \
            "" >> "${last_note}.md"
          fi
        else

          # Convert the episode name to a headline string.
          local episode_note="$(
            echo $episode | \
            sed 's|-|\ |g' | \
            awk '{for(i=1;i<=NF;i++){$i=toupper(substr($i,1,1)) substr($i,2)}}1' \
          )"

          # Generate a root document for the episode pointing to first frame.
          printf '%s\n' \
          "# ${episode_note}" \
          "" \
          "## Async Research Institute Confidential Records" \
          "" \
          "[[${this_note}|VHS-C Capture]]" \
          "" > "/research/${episode}/${episode_note}.md"
        fi

        # Latch the note data.
        last_note="${this_note}"
      done
    fi
  done
}

# Let the user know the project has finished running.
function confirm_process_completed {
  echo "All Available Video and Audio Has Been Downloaded."
  echo "* * *"
  echo "All Post-processing Steps Completed!"
}

function install {
  # Call all of our functions, contingent upon the previous success code.
  apk_update
  [ $? -eq 0 ] && apk_upgrade
  [ $? -eq 0 ] && install_python
  [ $? -eq 0 ] && verify_python_install
  [ $? -eq 0 ] && install_ffmpeg
  [ $? -eq 0 ] && verify_ffmpeg_install
  [ $? -eq 0 ] && install_youtube_dl
  [ $? -eq 0 ] && verify_youtube_dl_install
  [ $? -eq 0 ] && build_index_file video 271
  [ $? -eq 0 ] && build_index_file audio 140
  [ $? -eq 0 ] && verify_media_index_integrity
  [ $? -eq 0 ] && prepare_filesystem
  [ $? -eq 0 ] && download_any
  [ $? -eq 0 ] && export_frames
  [ $? -eq 0 ] && combine_video_and_audio
  [ $? -eq 0 ] && generate_obsidian_notes
  [ $? -eq 0 ] && confirm_process_completed
}

# Call the installation function.
install