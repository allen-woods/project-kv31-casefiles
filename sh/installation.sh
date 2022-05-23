#!/bin/sh

export YT_URL="https://www.youtube.com/playlist?list="
export PLAYLIST_ID="PLVAh-MgDVqvDUEq6qDXqORBioE4Yhol_z"
export MIN_WAIT=$(( 1 * 60 ))
export MAX_WAIT=$(( 5 * 60 ))

function print_success_fail {
  # Require an exit code as the only argument.
  if [ -z "${1}" ]; then
    printf '%s\n' \
    "" \
    "ERROR: You must pass an exit code." \
    "usage: ${0} <exit_code>"
    return 1
  fi

  # If the exit code is a numeric value larger than zero...
  if [ $1 -gt 0 ]; then
    # Inform the user the operation failed.
    echo -e "\033[0;31mFAILED\033[0m"
    # We can go no further.
    return 1
  fi

  # Inform the user the operation succeeded by default.
  echo -e "\033[1;32mSUCCESS\033[0m"
}

function apk_install {
  # Require a package name as the minimum number of arguments.
  if [ -z "${1}" ]; then
    echo "ERROR: You must pass a package name to install or an option flag."
    echo "usage: ${0} <pkg|flag> [[install_path] [symbolic_link]]"
    return 1
  fi

  case "${@}" in
    --update)
      # Print user feedback to the terminal.
      echo "Updating package repositories..." | tr -d '\n'
      
      # Attempt to update the package repositories.
      apk update 2>&1 >/dev/null
      
      # Print the result of the operation to the terminal.
      print_success_fail $?

      # Conditionally abort on failure.
      if [ $? -gt 0 ]; then
        return 1
      fi
      ;;
    --upgrade)
      # Print user feedback to the terminal.
      echo "Upgrading package versions..." | tr -d '\n'

      # Attempt to upgrade the package versions.
      apk upgrade 2>&1 >/dev/null

      # Print the result of the operation to the terminal.
      print_success_fail $?

      # Conditionally abort on failure.
      if [ $? -gt 0 ]; then
        return 1
      fi
      ;;
    *)
      # Print user feedback to the terminal.
      echo "Installing '${1}'..." | tr -d '\n'

      # Attempt to add the package requested silently.
      apk add $1 2>&1 >/dev/null

      # Print the result of the operation to the terminal.
      print_success_fail $?

      # Conditionally abort on failure.
      if [ $? -gt 0 ]; then
        return 1
      fi

      # If and only if both optional arguments are present...
      if [ ! -z "${2}" ] && [ ! -z "${3}" ]; then

        # If the install path doesn't exist for some reason...
        if [ ! -f $2 ]; then

          # Gracefully break out of our pretty text (tr -d '\n') and
          # inform the user an error occurred.
          printf '%s\n' "" "ERROR: Install path \"${2}\" not found."

          # We can go no further.
          return 1
        fi

        # Create the requested symlink.
        ln -s $2 $3
      fi
      ;;
  esac
}

function verify_install {
  # Require an executable name as the minimum number of arguments.
  if [ -z "${1}" ]; then
    printf '%s\n' \
    "" \
    "ERROR: Must pass name of binary and verification string as arguments." \
    "usage: ${0} <bin_name> <\"\$\(verification\)\">"
    return 1
  fi

  # Print user feedback to the terminal.
  echo "Verifying '${1}' installation..." | tr -d '\n'

  # If the verification string is empty...
  if [ -z "${2}" ]; then

    # ...Inform the user the installation failed.
    print_success_fail 1

    # We can go no further.
    return 1
  fi

  # Inform the user installation succeeded by default.
  print_success_fail 0
}

function install_youtube_dl {
  echo "Installing youtube-dl..." | tr -d '\n'
  # Download over wget.
  wget \
    -cq \
    -O /usr/bin/youtube-dl \
    https://yt-dl.org/downloads/latest/youtube-dl

  # Print user feedback to the terminal.
  print_success_fail $?

  # Conditionally abort on failure.
  if [ $? -gt 0 ]; then
    return 1
  fi

  # Alias and give executable permissions to binary.
  chmod a+rx /usr/bin/youtube-dl
}

function build_episode_list {
  # If a previous episode list exists, erase it.
  if [ -f episode_list ]; then
    rm -f episode_list
  fi

  echo "Building episode list..." | tr -d '\n'

  # Grab the titles of all videos in the playlist.
  youtube-dl \
    --yes-playlist \
    --get-title \
    "${YT_URL}${PLAYLIST_ID}" > episode_list

  print_success_fail $?

  if [ $? -gt 0 ]; then
    return 1
  fi
}

function format_episode_list {
  echo "Formatting episode list..." | tr -d '\n'

  # Process the titles through awk as originally handled using sed.
  awk --include inplace \
  '
  {
    sub(/^[^ ]{0,}[ ]{0,}[Backroms]{9}[ -]{1,3}/, "", $0);
    gsub(/[()]{1}/, "", $0);
    gsub(/[ ._]{1}/, "-", $0);
    print tolower($0);
  }
  ' episode_list

  print_success_fail $?

  if [ $? -gt 0 ]; then
    return 1
  fi
}

function export_episode_env_vars {
  echo "Exporting episode env vars..." | tr -d '\n'

  export EP_I=1

  # export the line count of the index file as EP_N.
  export EP_N=$( wc -l < episode_list )

  print_success_fail $?

  if [ $? -gt 0 ]; then
    return 1
  fi
}

function random_sleep {
  if [ -z "${1}" ] || [ -z "${2}" ] || [ $1 -eq $2 ]; then
    printf '%s\n' \
    "" \
    "ERROR: Must pass min and max values that are not equal." \
    "usage: ${0} <min> <max>"
    return 1
  fi

  local r_sleep=$( \
    awk \
    -v min=$1 \
    -v max=$2 \
    '
    BEGIN {
      srand();
      print int(min + rand() * (max - min + 1))
    }
    '
  )

  echo -e "\033[40m\033[1;37m • Sleeping for ${r_sleep} seconds...\033[0m" | \
  tr -d '\n'

  sleep "${r_sleep}s"

  echo -e "\033[42m\033[1;37m DONE! \033[0m"
}

function download_episodes {
  while [ $EP_I -le $EP_N ]; do

    local ep_name=$( sed "${EP_I}q;d" < episode_list )

    if [ ! -d /research/$ep_name ] || [ $EP_RETRY -eq 1 ]; then

      if [ $EP_I -gt 1 ]; then
        random_sleep $MIN_WAIT $MAX_WAIT
      fi

# - - BEGIN: Video
      echo "Requesting video url: '${ep_name}'..." | tr -d '\n'

      local video_url=$( \
        youtube-dl \
        --no-playlist \
        --playlist-start $EP_I \
        --playlist-end $EP_I \
        --format 271 \
        --get-url \
        "${YT_URL}${PLAYLIST_ID}" >&1 \
      )

      print_success_fail $?

      if [ $? -gt 0 ]; then
        return 1
      fi

      echo "Parsing video bytesize: '${ep_name}'..." | tr -d '\n'

      local video_bytes=$( \
        echo $video_url | \
        awk \
        '
        {
          sub(/^[^ ]{0,}[&clen=]{6}/, "", $0);
          sub(/[&dur=]{5}[^ ]{0,}$/, "", $0);
          print
        }
        ' \
      )

      print_success_fail $?

      if [ $? -gt 0 ]; then
        return 1
      fi

      if [ ! -d /research/$ep_name/video ]; then
        echo "Preparing filesystem..." | tr -d '\n'
        
        mkdir -pm 0755 /research/$ep_name/video

        print_success_fail $?

        if [ $? -gt 0 ]; then
          return 1
        fi
      fi

      echo "Downloading hi-res footage: '${ep_name}'..." | tr -d '\n'

      youtube-dl \
      --no-playlist \
      --limit-rate 50K \
      --retries infinite \
      --fragment-retries infinite \
      --buffer-size 16K \
      --http-chunk-size 5M \
      --continue \
      --sleep-interval $MIN_WAIT \
      --max-sleep-interval $MAX_WAIT \
      --output /research/$ep_name/video/$ep_name-video-only.webm \
      $video_url 2>&1 >/dev/null

      print_success_fail $?

      if [ $? -gt 0 ]; then
        return 1
      fi

      if [ ! -f /research/$ep_name/video/$ep_name-video-only.webm ]; then
        export EP_RETRY=1
        continue
      fi

      echo "Verifying download..." | tr -d '\n'

      local video_disk=$( \
        wc -c /research/$ep_name/video/$ep_name-video-only.webm \
      )

      if [ $video_disk -ne $video_bytes \
      ]; then
        print_success_fail 1
        export EP_RETRY=1
        continue
      fi

      if [ $EP_RETRY -eq 1 ]; then
        unset $EP_RETRY
      fi

      print_success_fail 0
# - - END: Video

      random_sleep $MIN_WAIT $MAX_WAIT

# - - BEGIN: Audio
      echo "Requesting audio url: '${ep_name}'..." | tr -d '\n'

      local audio_url=$( \
        youtube-dl \
        --no-playlist \
        --playlist-start $EP_I \
        --playlist-end $EP_I \
        --format 140 \
        --get-url \
        "${YT_URL}${PLAYLIST_ID}" >&1 \
      )

      print_success_fail $?

      if [ $? -gt 0 ]; then
        return 1
      fi

      echo "Parsing audio bytesize: '${ep_name}'..." | tr -d '\n'

      local audio_bytes=$( \
        echo $audio_url | \
        awk \
        '
        {
          sub(/^[^ ]{0,}[&clen=]{6}/, "", $0);
          sub(/[&dur=]{5}[^ ]{0,}$/, "", $0);
          print
        }
        ' \
      )

      print_success_fail $?

      if [ $? -gt 0 ]; then
        return 1
      fi

      if [ ! -d /research/$ep_name/audio ]; then
        echo "Preparing filesystem..." | tr -d '\n'
        
        mkdir -m 0755 /research/$ep_name/audio

        print_success_fail $?

        if [ $? -gt 0 ]; then
          return 1
        fi
      fi

      echo "Downloading hi-res audio: '${ep_name}'..." | tr -d '\n'

      youtube-dl \
      --no-playlist \
      --limit-rate 50K \
      --retries infinite \
      --fragment-retries infinite \
      --buffer-size 16K \
      --http-chunk-size 5M \
      --continue \
      --sleep-interval $MIN_WAIT \
      --max-sleep-interval $MAX_WAIT \
      --output /research/$ep_name/audio/$ep_name-audio-only.m4a \
      $audio_url 2>&1 >/dev/null

      print_success_fail $?

      if [ $? -gt 0 ]; then
        return 1
      fi

      if [ ! -f /research/$ep_name/audio/$ep_name-audio-only.m4a ]; then
        export EP_RETRY=1
        continue
      fi

      echo "Verifying download..." | tr -d '\n'

      local audio_disk=$( \
        wc -c /research/$ep_name/audio/$ep_name-audio-only.m4a \
      )

      if [ $audio_disk -ne $audio_bytes \
      ]; then
        print_success_fail 1
        export EP_RETRY=1
        continue
      fi

      if [ $EP_RETRY -eq 1 ]; then
        unset $EP_RETRY
      fi

      print_success_fail 0
# - - END: Audio

      if [ ! -f /research/$ep_name/$ep_name.webm ]; then
        echo "Combining video and audio: '${ep_name}'."
        echo -e "\033[0;31m* * * CAUTION: * * *"
        echo -e "- This media post-processing consumes a lot of CPU."
        echo -e "- Running heavy background processes is unadvisable.\033[0m"

        ffmpeg \
        -i /research/$ep_name/video/$ep_name-video-only.webm \
        -i /research/$ep_name/audio/$ep_name-audio-only.m4a \
        -c:v libvpx-vp9 -crf 0 \
        -c:a libopus -q:a 0 -b:a 128k \
        /research/$ep_name/$ep_name.webm

        print_success_fail $?

        if [ $? -gt 0 ]; then
          return 1
        fi
      fi

      if [ ! -d /research/$ep_name/frames ]; then
        echo "Preparing filesystem..." | tr -d '\n'
        
        mkdir -m 0755 /research/$ep_name/frames

        print_success_fail $?

        if [ $? -gt 0 ]; then
          return 1
        fi

        echo "Exporting frames: '${ep_name}'..." | tr -d '\n'

        ffmpeg \
        -i /research/$ep_name/video/$ep_name-video-only.webm \
        -vf scale=320:240,setsar=1:1 \
        /research/$ep_name/frames/$ep_name-frame-%08d.png

        print_success_fail $?

        if [ $? -gt 0 ]; then
          return 1
        fi
      fi

      # Generate notes.
    fi

    if [ -z "${EP_RETRY}" ]; then
      EP_I=$(( $EP_I + 1 ))
    fi
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

  # APK UPDATE
  apk_install --update

  # APK UPGRADE
  [ $? -eq 0 ] && apk_install --upgrade

  # GAWK
  [ $? -eq 0 ] && apk_install gawk
  [ $? -eq 0 ] && \
  verify_install gawk \
  $( \
    gawk \
    --help 2>&1 | \
    tr -d '\n' | \
    awk '/POSIX or GNU/ { print $2 }' \
  )

  # PYTHON
  [ $? -eq 0 ] && apk_install python3 /usr/bin/python3 /usr/bin/python
  [ $? -eq 0 ] && \
  verify_install python \
  $( \
    python \
    --version | \
    awk '/Python/ { print $1 }' \
  )

  # FFMPEG
  [ $? -eq 0 ] && apk_install ffmpeg
  [ $? -eq 0 ] && \
  verify_install ffmpeg \
  $( \
    ffmpeg 2>&1 | \
    tr -d '\n' | \
    awk '/ffmpeg/ { print $1 }' \
  )

  # WGET
  [ $? -eq 0 ] && apk_install wget
  [ $? -eq 0 ] && \
  verify_install wget \
  $( \
    wget --help 2>&1 | \
    awk '/GNU Wget/ { print $1 }' \
  )

  # YOUTUBE-DL
  [ $? -eq 0 ] && install_youtube_dl
  [ $? -eq 0 ] && \
  verify_install youtube-dl \
  $( \
    youtube-dl 2>&1 | \
    tr -d '\n' | \
    awk '{ print $2 }' \
  )

  # Setup the default boilerplate.
  [ $? -eq 0 ] && build_episode_list
  [ $? -eq 0 ] && format_episode_list
  [ $? -eq 0 ] && export_episode_env_vars
  [ $? -eq 0 ] && download_episodes
  # [ $? -eq 0 ] && build_index_file video 271
  # [ $? -eq 0 ] && build_index_file audio 140
  # [ $? -eq 0 ] && verify_media_index_integrity
  # [ $? -eq 0 ] && prepare_filesystem
  # [ $? -eq 0 ] && download_any
  # [ $? -eq 0 ] && export_frames
  # [ $? -eq 0 ] && combine_video_and_audio
  # [ $? -eq 0 ] && generate_obsidian_notes
  # [ $? -eq 0 ] && confirm_process_completed
}

# Call the installation function.
install