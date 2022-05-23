#!/bin/sh

# YouTube env vars.
export YT_URL="https://www.youtube.com/playlist?list="
export PLAYLIST_ID="PLVAh-MgDVqvDUEq6qDXqORBioE4Yhol_z"

# Global min/max values for randomized sleep.
export MIN_WAIT=$(( 1 * 60 ))
export MAX_WAIT=$(( 5 * 60 ))

# Utility function for checking network connectivity.
function is_internet_accessible {
  # Request google silently.
  wget --spider https://www.google.com -o /dev/null

  if [ $? -gt 0 ]; then
    echo -e "\033[0;105m\033[1;36m • NETWORK DISCONNECTED • \033[0m"
    return 1
  fi
}

# Utility function for printing success/failed to terminal.
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

# Utility function for dynamic package management via apk.
function apk_install {
  # Require a package name as the minimum number of arguments.
  if [ -z "${1}" ]; then
    echo "ERROR: You must pass a package name to install or an option flag."
    echo "usage: ${0} <pkg|flag> [[install_path] [symbolic_link]]"
    return 1
  fi

  case "${@}" in
    --update)
      # Run network test before performing request(s).
      is_internet_accessible
      # Conditionally abort on failure.
      if [ $? -gt 0 ]; then
        return 1
      fi

      # Print user feedback to the terminal.
      printf '%s' "Updating package repositories..."
      
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
      # Run network test before performing request(s).
      is_internet_accessible
      # Conditionally abort on failure.
      if [ $? -gt 0 ]; then
        return 1
      fi

      # Print user feedback to the terminal.
      printf '%s' "Upgrading package versions..."

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
      # Run network test before performing request(s).
      is_internet_accessible
      # Conditionally abort on failure.
      if [ $? -gt 0 ]; then
        return 1
      fi

      # Print user feedback to the terminal.
      printf '%s' "Installing '${1}'..."

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

# Utility function for verifying attempted installations.
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
  printf '%s' "Verifying '${1}' installation..."

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

# Utility function specific to youtube-dl installation use case.
function install_youtube_dl {
  # Run network test before performing request(s).
  is_internet_accessible
  # Conditionally abort on failure.
  if [ $? -gt 0 ]; then
    return 1
  fi

  # Print user feedback to the terminal.
  printf '%s' "Installing 'youtube-dl'..."

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

# Create the list of episode names in a file at the root of the container.
function build_episode_list {
  # If a previous episode list exists, erase it.
  if [ -f episode_list ]; then
    rm -f episode_list
  fi

  # Run network test before performing request(s).
  is_internet_accessible
  # Conditionally abort on failure.
  if [ $? -gt 0 ]; then
    return 1
  fi

  # Print user feedback to the terminal.
  printf '%s' "Building episode list..."

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

# Format the entries of the episode list into slug-case/kebab-case.
function format_episode_list {
  # Print user feedback to the terminal.
  printf '%s' "Formatting episode list..."

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

# Export env vars for use with tracking which episode we're processing.
function export_episode_env_vars {
  # Print user feedback to the terminal.
  printf '%s' "Exporting episode env vars..."

  # Export the current episode's index.
  export EP_I=1

  # export the line count of the episode list as EP_N.
  export EP_N=$( wc -l < episode_list )

  print_success_fail $?

  if [ $? -gt 0 ]; then
    return 1
  fi
}

# Utility function for achieving randomized sleep native to the terminal.
function random_sleep {
  # Require two arguments that are not equal.
  if [ -z "${1}" ] || [ -z "${2}" ] || [ ! $1 -lt $2 ]; then
    printf '%s\n' \
    "" \
    "ERROR: Must pass min value and max value that are not equal." \
    "usage: ${0} <min> <max>"
    return 1
  fi

  # Store a randomly generated number in the range [min, max].
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

  # Print user feedback to the terminal.
  echo -e "\033[40m\033[1;37m • Sleeping for ${r_sleep} seconds...\033[0m" | \
  tr -d '\n'

  # Pause executing script(s) for a random amount of time.
  sleep "${r_sleep}s"

  echo -e "\033[42m\033[1;37m DONE! \033[0m"
}

# Heavy lifting function; pulls files down, generates supportive materials.
function download_and_process_episodes {
  # While there are still episodes left to process...
  while [ $EP_I -le $EP_N ]; do
    # Extract the name of the episode given by item $EP_I.
    local ep_name=$( \
      cat episode_list | \
      awk -v "ep=${EP_I}" 'NR==ep { print }' \
    )

    # If the folder for this episode does not exist...
    # OR, if we are retrying the current episode again...
    if [ ! -d /research/$ep_name ] || [ $EP_RETRY -eq 1 ]; then

      # Sleep randomly before running youtube-dl again to prevent
      # "connection reset by peer" from API.
      if [ $EP_I -gt 1 ]; then
        random_sleep $MIN_WAIT $MAX_WAIT
      fi

      # Run network test before performing request(s).
      is_internet_accessible
      # Conditionally abort on failure.
      if [ $? -gt 0 ]; then
        return 1
      fi

# - - BEGIN: Video
      printf '%s' "Requesting video url: '${ep_name}'..."

      # Request the url of the video stream.
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

      printf '%s' "Parsing video bytesize: '${ep_name}'..."

      # Parse the byte size of the requested video stream.
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

      # If the video subdirectory for this episode doesn't exist...
      if [ ! -d /research/$ep_name/video ]; then
        # Print user feedback to the terminal.
        printf '%s' "Preparing filesystem..."
        
        # ...Create the path.
        mkdir -pm 0755 /research/$ep_name/video

        print_success_fail $?

        if [ $? -gt 0 ]; then
          return 1
        fi
      fi

      # NOTE:
      # We do not wrap the above if statement around processing of the video
      # stream in its entirety because we want to allow for non-volatile
      # retries of interrupted downloads.

      # Run network test before performing request(s).
      is_internet_accessible
      # Conditionally abort on failure.
      if [ $? -gt 0 ]; then
        return 1
      fi

      # Print user feedback to the terminal.
      printf '%s' "Downloading hi-res footage: '${ep_name}'..."

      # Download the requested video stream silently.
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

      # If the above output file does not exist, we have to retry it.
      if [ ! -f /research/$ep_name/video/$ep_name-video-only.webm ]; then
        export EP_RETRY=1
        continue
      fi

      # Print user feedback to the terminal.
      printf '%s' "Verifying download..."

      # Extract the final size on disk of the output file.
      local video_disk=$( \
        wc -c /research/$ep_name/video/$ep_name-video-only.webm \
      )

      # If the expected size and size on disk do not match...
      if [ "${video_disk}" != "${video_bytes}" ]; then
        # ...We must retry.
        print_success_fail 1
        export EP_RETRY=1
        continue
      fi

      # If we have made it this far...
      if [ $EP_RETRY -eq 1 ]; then
        # ...It is safe to delete the retry flag.
        unset $EP_RETRY
      fi

      print_success_fail 0
# - - END: Video

      # Sleep randomly between media stream downloads to prevent
      # "connection reset by peer" from API.
      random_sleep $MIN_WAIT $MAX_WAIT

      # Run network test before performing request(s).
      is_internet_accessible
      # Conditionally abort on failure.
      if [ $? -gt 0 ]; then
        return 1
      fi

# - - BEGIN: Audio
      printf '%s' "Requesting audio url: '${ep_name}'..."

      # Request the url of the audio stream.
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

      # Print user feedback to the terminal.
      printf '%s' "Parsing audio bytesize: '${ep_name}'..."

      # Parse the byte size of the requested audio stream.
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

      # If the audio subdirectory for this episode doesn't exist...
      if [ ! -d /research/$ep_name/audio ]; then
        # Print user feedback to the terminal.
        printf '%s' "Preparing filesystem..."
        
        # ...Create the subdirectory.
        mkdir -m 0755 /research/$ep_name/audio

        print_success_fail $?

        if [ $? -gt 0 ]; then
          return 1
        fi
      fi

      # Run network test before performing request(s).
      is_internet_accessible
      # Conditionally abort on failure.
      if [ $? -gt 0 ]; then
        return 1
      fi

      # Print user feedback to the terminal.
      printf '%s' "Downloading hi-res audio: '${ep_name}'..."

      # Download the requested audio stream silently.
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

      # If the above output file does not exist, we have to retry it.
      if [ ! -f /research/$ep_name/audio/$ep_name-audio-only.m4a ]; then
        export EP_RETRY=1
        continue
      fi

      # Print user feedback to the terminal.
      printf '%s' "Verifying download..."

      # Extract the final size on disk of the output file.
      local audio_disk=$( \
        wc -c /research/$ep_name/audio/$ep_name-audio-only.m4a \
      )

      # If the expected size and size on disk do not match...
      if [ "${audio_disk}" != "${audio_bytes}" ]; then
        # ...We must retry.
        print_success_fail 1
        export EP_RETRY=1
        continue
      fi

      # If we have made it this far...
      if [ $EP_RETRY -eq 1 ]; then
        # ...It is safe to delete the retry flag.
        unset $EP_RETRY
      fi

      print_success_fail 0
# - - END: Audio

      # If a merged audio/video file does not exist for this episode...
      if [ ! -f /research/$ep_name/$ep_name.webm ]; then
        # Print user feedback to the terminal.
        echo "Combining video and audio: '${ep_name}'."
        echo -e "\033[0;31m* * * CAUTION: * * *"
        echo -e "- This media post-processing consumes a lot of CPU."
        echo -e "- Running heavy background processes is unadvisable.\033[0m"

        # ...Generate a merged audio/video file.
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

      # If a frames subdirectory doesn't exist for this episode...
      if [ ! -d /research/$ep_name/frames ]; then
        # Print user feedback to the terminal.
        printf '%s' "Preparing filesystem..."
        
        # ...Create the subdirectory.
        mkdir -m 0755 /research/$ep_name/frames

        print_success_fail $?

        if [ $? -gt 0 ]; then
          return 1
        fi

        # Print user feedback to the terminal.
        printf '%s' "Exporting frames: '${ep_name}'..."

        # Export the frames in native VHS-C resolution to save space.
        ffmpeg \
        -i /research/$ep_name/video/$ep_name-video-only.webm \
        -vf scale=320:240,setsar=1:1 \
        /research/$ep_name/frames/$ep_name-frame-%08d.png

        print_success_fail $?

        if [ $? -gt 0 ]; then
          return 1
        fi
      fi

      # If a notes directory does not exist...
      if [ ! -d /research/$ep_name/notes ]; then

        # Print user feedback to the terminal.
        echo "Generating Obsidian Notes for '${ep_name}'."

        # Create the notes directory for this episode.
        mkdir -m 0755 /research/$ep_name/notes

        # Variables to track linear time across frames.
        local last_note=
        local this_note=

        # Iterate across the frames exported from this episode.
        for image in /research/$ep_name/frames/*; do
          # Strip the path from the image name.
          image=$( basename $image )

          # Convert the image name to a headline string.
          this_note="$(
            echo $image | \
            awk \
            '
            {
              sub(/[.png]{4}/, "", $0);
              gsub(/-/, " ", $0);
              for(i=1;i<=NF;i++){
                $i=toupper(substr($i,1,1)) substr($i,2)
              };
              print
            }
            ' \
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
            local ep_note="$(
              echo $ep_name | \
              awk \
              '
              {
                gsub(/-/, " ", $0);
                for(i=1;i<=NF;i++){
                  $i=toupper(substr($i,1,1)) substr($i,2)
                };
                print
              }' \
            )"

            # Generate a root document for the episode pointing to first frame.
            printf '%s\n' \
            "# ${ep_note}" \
            "" \
            "## Async Research Institute Confidential Records" \
            "" \
            "[[${this_note}|VHS-C Capture]]" \
            "" > "/research/${ep_name}/${ep_note}.md"
          fi

          # Latch the note data.
          last_note="${this_note}"
        done
      fi
    fi

    # Only permit incrementing to the next episode if retries of the
    # current episode are not needed.
    if [ -z "${EP_RETRY}" ]; then
      EP_I=$(( $EP_I + 1 ))
    fi
  done
}

# Let the user know the project has finished running.
function confirm_process_completed {
  echo "All Available Video and Audio Has Been Downloaded."
  echo "* * *"
  echo "All Post-processing Steps Completed!"
}

# Entry point.
function install {
  # Call all of our functions, contingent upon the previous success code.

  # Run network test before performing request(s).
  is_internet_accessible
  # Conditionally abort on failure.
  if [ $? -gt 0 ]; then
    return 1
  fi

  # APK UPDATE
  [ $? -eq 0 ] && apk_install --update

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
  [ $? -eq 0 ] && download_and_process_episodes
  [ $? -eq 0 ] && confirm_process_completed
}

# Call the installation function.
install