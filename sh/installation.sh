#!/bin/sh
set -e

# Pretty print env vars.
export PRETTY_LINE_MAX_W=128
export PRETTY_LINE_NF_W=9
export PRETTY_CH=_

# YouTube env vars.
export YT_URL="https://www.youtube.com/playlist?list="
export PLAYLIST_ID="PLVAh-MgDVqvDUEq6qDXqORBioE4Yhol_z"

# Global min/max values for randomized sleep.
export MIN_WAIT=$(( 1 * 60 ))
export MAX_WAIT=$(( 3 * 60 ))

# Utility function to provide pretty printing before gawk is installed.
function patch_with_char {
  if [ -z "${1}" ] || [ -z "${2}" ]; then
    printf '%s\n' \
    "ERROR: Must pass quoted string and padding character as arguments." \
    "usage: ${0} <\"str\"> <char> [printf_fmt_str]"
    return 1
  fi

  local msg="$( printf "${3:-"%s"}" "${1}" | tr -d '\n' )"
  local ch="${2}"

  # Only known gremlin: there is a single character too few (+1 below).
  local width=$(( $PRETTY_LINE_MAX_W - ${#msg} - $PRETTY_LINE_NF_W + 1 ))

  printf "${3:-"%s"}" "${1}"
  printf '\e[38;2;127;127;127;02m%s\e[m' \
  "$( seq -s ${ch} ${width} | tr -d '[:digit:]' )"
}

# Utility function for checking network connectivity.
function is_internet_accessible {
  patch_with_char "Network" "." '\e[0;34m • %s\e[m' || true

  wget -qc \
  --spider \
  https://www.google.com || true

  if [ $? -gt 0 ]; then
    printf '\e[0;105m\e[1;36m %s \e[m\n' "OFFLINE"
    return 1
  fi

  printf '\e[1;34m\e[40m   %s    \e[m\n' "OK"
}

# Utility function for printing success/failure to terminal.
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
    printf '\e[0;37m\e[41m %s \e[m\n' "FAILURE"
    # We can go no further.
    return 1
  fi

  # Inform the user the operation succeeded by default.
  printf '\e[1;37m\e[42m %s \e[m\n' "SUCCESS"
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

      # Print user feedback to the terminal.
      patch_with_char \
      "Updating package repositories" \
      "${PRETTY_CH}" \
      '\e[0;36m%s\e[m' || true
      
      # Attempt to update the package repositories.
      apk update 2>&1 >/dev/null || true
      
      # Print the result of the operation to the terminal.
      print_success_fail $?
      ;;
    --upgrade)
      # Run network test before performing request(s).
      is_internet_accessible

      # Print user feedback to the terminal.
      patch_with_char \
      "Upgrading package versions" \
      "${PRETTY_CH}" \
      '\e[0;36m%s\e[m' || true

      # Attempt to upgrade the package versions.
      apk upgrade 2>&1 >/dev/null || true

      # Print the result of the operation to the terminal.
      print_success_fail $?
      ;;
    *)
      # Run network test before performing request(s).
      is_internet_accessible

      # Print user feedback to the terminal.
      patch_with_char \
      "Installing '${1}'" \
      "${PRETTY_CH}" \
      '\e[0;36m%s\e[m' || true

      # Attempt to add the package requested silently.
      apk add $1 2>&1 >/dev/null || true

      # Print the result of the operation to the terminal.
      print_success_fail $?

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
  patch_with_char \
  "Verifying '${1}' installation" \
  "${PRETTY_CH}" \
  '\e[0;32m%s\e[m' || true

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

  # Print user feedback to the terminal.
  patch_with_char \
  "Installing 'youtube-dl'" \
  "${PRETTY_CH}" \
  '\e[0;36m%s\e[m' || true

  # Download over wget.
  wget -qc \
  -O /usr/bin/youtube-dl \
  https://yt-dl.org/downloads/latest/youtube-dl || true

  # Print user feedback to the terminal.
  print_success_fail $?

  # Alias and give executable permissions to binary.
  chmod a+rx /usr/bin/youtube-dl || true
}

# Create the list of episode names in a file at the root of the container.
function build_episode_list {
  # If a previous episode list exists, erase it.
  if [ -f episode_list ]; then
    rm -f episode_list
  fi

  # Run network test before performing request(s).
  is_internet_accessible

  # Print user feedback to the terminal.
  patch_with_char \
  "Building episode list" \
  "${PRETTY_CH}" \
  '\e[0;33m%s\e[m' || true

  # Grab the titles of all videos in the playlist.
  youtube-dl \
  --yes-playlist \
  --get-title \
  "${YT_URL}${PLAYLIST_ID}" > episode_list || true

  print_success_fail $?
}

# Format the entries of the episode list into slug-case/kebab-case.
function format_episode_list {
  # Print user feedback to the terminal.
  patch_with_char \
  "Formatting episode list" \
  "${PRETTY_CH}" \
  '\e[0;33m%s\e[m' || true

  # Process the titles through awk as originally handled using sed.
  awk --include inplace \
  '
  {
    sub(/^[^ ]{0,}[ ]{0,}[Backroms]{9}[ -]{1,3}/, "", $0);
    gsub(/[()]{1}/, "", $0);
    gsub(/[ ._]{1}/, "-", $0);
    print tolower($0);
  }
  ' episode_list || true

  print_success_fail $?
}

# Export env vars for use with tracking which episode we're processing.
function export_episode_env_vars {
  # Print user feedback to the terminal.
  patch_with_char \
  "Exporting episode env vars" \
  "${PRETTY_CH}" \
  '\e[0;36m%s\e[m' || true

  # Export the current episode's index.
  export EP_I=1

  # export the line count of the episode list as EP_N.
  export EP_N=$( wc -l < episode_list | awk '{ print $1 }' ) || true

  print_success_fail $?
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
  patch_with_char \
  "Sleeping for ${r_sleep} seconds" \
  "${PRETTY_CH}" \
  '\e[0;35m • %s\e[m' || true

  # Pause executing script(s) for a random amount of time.
  sleep "${r_sleep}s"

  printf '\e[1;37m\e[104m  %s  \e[m\n' "Done."
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
    if [ ! -d research/$ep_name ]; then

      # Sleep randomly before running youtube-dl again to prevent
      # "connection reset by peer" or 403 Forbidden from API.
      random_sleep $MIN_WAIT $MAX_WAIT

      # Run network test before performing request(s).
      is_internet_accessible

# - - BEGIN: Video
      patch_with_char \
      "Requesting video url: '${ep_name}'" \
      "${PRETTY_CH}" \
      '\e[0;33m%s\e[m' || true

      # Request the url of the video stream.
      local video_url=$( \
        youtube-dl \
        --playlist-start $EP_I \
        --playlist-end $EP_I \
        --no-playlist \
        --get-url \
        --format 271 \
        "${YT_URL}${PLAYLIST_ID}" >&1 \
      ) || true

      print_success_fail $?

      patch_with_char \
      "Parsing video byte size: '${ep_name}'" \
      "${PRETTY_CH}" \
      '\e[0;33m%s\e[m' || true

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
      ) || true

      print_success_fail $?

      # If the video subdirectory for this episode doesn't exist...
      if [ ! -d research/$ep_name/video ]; then
        # Print user feedback to the terminal.
        patch_with_char \
        "Preparing filesystem" \
        "${PRETTY_CH}" \
        '\e[0;36m%s\e[m' || true
        
        # ...Create the path.
        mkdir -pm 0755 research/$ep_name/video || true

        print_success_fail $?
      fi

      # NOTE:
      # We do not wrap the above if statement around processing of the video
      # stream in its entirety because we want to allow for non-volatile
      # retries of interrupted downloads.

      # Sleep randomly before running youtube-dl again to prevent
      # "connection reset by peer" or 403 Forbidden from API.
      random_sleep $MIN_WAIT $MAX_WAIT

      # Run network test before performing request(s).
      is_internet_accessible

      # Print user feedback to the terminal.
      patch_with_char \
      "Downloading hi-res footage: '${ep_name}'" \
      "${PRETTY_CH}" \
      '\e[0;35m • %s\e[m' || true

      printf '\e[1;37m\e[45m %s \e[m\n' "WAIT..."

      # Download the requested video stream.

      youtube-dl \
      --playlist-start $EP_I \
      --playlist-end $EP_I \
      --no-playlist \
      --retries infinite \
      --fragment-retries infinite \
      --buffer-size 16K \
      --http-chunk-size 5M \
      --continue \
      --format 271 \
      --output research/$ep_name/video/$ep_name-video-only.webm \
      --sleep-interval $MIN_WAIT \
      --max-sleep-interval $MAX_WAIT \
      "${YT_URL}${PLAYLIST_ID}" || true

      local v_ec=$?

      patch_with_char \
      "Download" \
      "${PRETTY_CH}" \
      '\e[0;35m • %s\e[m' || true

      print_success_fail $v_ec

      # Extract the final size on disk of the output file.
      local video_disk=$( \
        wc -c research/$ep_name/video/$ep_name-video-only.webm | \
        awk '{ print $1 }' \
      )

      patch_with_char \
      "Expected: ${video_bytes}, Got: ${video_disk}" \
      "${PRETTY_CH}" \
      '\e[1;36m\e[46m >> %s\e[m' || true

      printf '\e[1;36m\e[46m  %s  \e[m\n' "BYTES"
# - - END: Video

      # Sleep randomly before running youtube-dl again to prevent
      # "connection reset by peer" or 403 Forbidden from API.
      random_sleep $MIN_WAIT $MAX_WAIT

      # Run network test before performing request(s).
      is_internet_accessible

# - - BEGIN: Audio
      patch_with_char \
      "Requesting audio url: '${ep_name}'" \
      "${PRETTY_CH}" \
      '\e[0;33m%s\e[m' || true

      # Request the url of the audio stream.
      local audio_url=$( \
        youtube-dl \
        --playlist-start $EP_I \
        --playlist-end $EP_I \
        --no-playlist \
        --get-url \
        --format 140 \
        "${YT_URL}${PLAYLIST_ID}" >&1 \
      ) || true

      print_success_fail $?

      # Print user feedback to the terminal.
      patch_with_char \
      "Parsing audio bytesize: '${ep_name}'" \
      "${PRETTY_CH}" \
      '\e[0;33m%s\e[m' || true

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
      ) || true

      print_success_fail $?

      # If the audio subdirectory for this episode doesn't exist...
      if [ ! -d research/$ep_name/audio ]; then
        # Print user feedback to the terminal.
        patch_with_char \
        "Preparing filesystem" \
        "${PRETTY_CH}" \
        '\e[0;36m%s\e[m' || true
        
        # ...Create the subdirectory.
        mkdir -m 0755 research/$ep_name/audio || true

        print_success_fail $?
      fi

      # Run network test before performing request(s).
      is_internet_accessible

      # Print user feedback to the terminal.
      patch_with_char \
      "Downloading hi-res audio: '${ep_name}'" \
      "${PRETTY_CH}" \
      '\e[0;35m • %s\e[m' || true

      printf '\e[1;37m\e[45m %s \e[m\n' "WAIT..."

      # Download the requested audio stream.
      youtube-dl \
      --playlist-start $EP_I \
      --playlist-end $EP_I \
      --no-playlist \
      --retries infinite \
      --fragment-retries infinite \
      --buffer-size 16K \
      --http-chunk-size 5M \
      --continue \
      --format 140 \
      --output research/$ep_name/audio/$ep_name-audio-only.m4a \
      --sleep-interval $MIN_WAIT \
      --max-sleep-interval $MAX_WAIT \
      "${YT_URL}${PLAYLIST_ID}" || true

      local a_ec=$?

      patch_with_char \
      "Download" \
      "${PRETTY_CH}" \
      '\e[0;35m • %s\e[m' || true

      print_success_fail $a_ec

      # Extract the final size on disk of the output file.
      local audio_disk=$( \
        wc -c research/$ep_name/audio/$ep_name-audio-only.m4a | \
        awk '{ print $1 }' \
      )

      patch_with_char \
      "Expected: ${audio_bytes}, Got: ${audio_disk}" \
      "${PRETTY_CH}" \
      '\e[1;36m\e[46m >> %s\e[m' || true

      printf '\e[1;36m\e[46m  %s  \e[m\n' "BYTES"
# - - END: Audio

      # If a merged audio/video file does not exist for this episode...
      if [ ! -f research/$ep_name/$ep_name.webm ]; then
        # Print user feedback to the terminal.
        patch_with_char \
        "Combining video and audio: '${ep_name}'" \
        "${PRETTY_CH}" \
        '\e[0;35m • %s\e[m' || true

        printf '\e[1;37m\e[45m %s \e[m\n' "WAIT..."

        # ...Generate a merged audio/video file.
        ffmpeg \
        -i research/$ep_name/video/$ep_name-video-only.webm \
        -i research/$ep_name/audio/$ep_name-audio-only.m4a \
        -c:v copy \
        -c:a libopus -b:a 192K \
        research/$ep_name/$ep_name.webm || true

        local cav_ec=$?

        patch_with_char \
        "Combination" \
        "${PRETTY_CH}" \
        '\e[0;35m • %s\e[m' || true

        print_success_fail $cav_ec
      fi

      # If a frames subdirectory doesn't exist for this episode...
      if [ ! -d research/$ep_name/frames ]; then
        # Print user feedback to the terminal.
        patch_with_char \
        "Preparing filesystem" \
        "${PRETTY_CH}" \
        '\e[0;36m%s\e[m' || true
        
        # ...Create the subdirectory.
        mkdir -m 0755 research/$ep_name/frames || true

        print_success_fail $?
      fi

      # Print user feedback to the terminal.
      patch_with_char \
      "Exporting frames: '${ep_name}'" \
      "${PRETTY_CH}" \
      '\e[0;35m • %s\e[m' || true

      printf '\e[1;37m\e[45m %s \e[m\n' "WAIT..."

      # Export the frames in native VHS-C resolution to save space.
      ffmpeg \
      -i research/$ep_name/video/$ep_name-video-only.webm \
      -vf scale=320:240,setsar=1:1 \
      research/$ep_name/frames/$ep_name-frame-%08d.png || true

      local ef_ec=$?

      patch_with_char \
      "Export" \
      "${PRETTY_CH}" \
      '\e[0;35m • %s\e[m' || true

      print_success_fail $ef_ec

      # If a notes directory does not exist...
      if [ ! -d research/$ep_name/notes ]; then
        # Print user feedback to the terminal.
        patch_with_char \
        "Preparing filesystem" \
        "${PRETTY_CH}" \
        '\e[0;36m%s\e[m' || true

        # Create the notes directory for this episode.
        mkdir -m 0755 research/$ep_name/notes || true

        print_success_fail $?
      fi

      # Print user feedback to the terminal.
      patch_with_char \
      "Generating Obsidian Notes for '${ep_name}'" \
      "${PRETTY_CH}" \
      '\e[0;35m • %s\e[m' || true

      printf '\e[1;37m\e[45m %s \e[m\n' "WAIT..."

      # Variables to track linear time across frames.
      local last_note=
      local this_note=

      # Iterate across the frames exported from this episode.
      for image in research/$ep_name/frames/*; do
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

        if [ ! -f "research/${ep_name}/notes/${this_note}.md" ]; then

          # Print the information regarding this image into its note.
          printf '%s\n' \
          "---" \
          "tags: ${ep_name}" \
          "---" \
          "# ${this_note}" \
          "" \
          "![[../frames/${image}]]" \
          "" > "research/${ep_name}/notes/${this_note}.md"

          # If we have generated at least one note previously...
          if [ ! -z "${last_note}" ]; then

            # And if the two strings are not the same...
            if [ "${last_note}" != "${this_note}" ]; then

              # ...Append a reference to last note on to the end of this note.
              printf '%s\n' \
              "## Prev Frame" \
              "" \
              "[[${last_note}]]" \
              "" >> "research/${ep_name}/notes/${this_note}.md"

              # ...Append a reference to this note on to the end of last note.
              printf '%s\n' \
              "## Next Frame" \
              "" \
              "[[${this_note}]]" \
              "" >> "research/${ep_name}/notes/${last_note}.md"
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
            "---" \
            "tags: ${ep_name}" \
            "---" \
            "# ${ep_note}" \
            "" \
            "## Async Research Institute Confidential Records" \
            "" \
            "[[${this_note}|VHS-C Capture]]" \
            "" > "research/${ep_name}/${ep_note}.md"
          fi

          # Latch the note data.
          last_note="${this_note}"
        fi
      done

      patch_with_char \
      "Generation" \
      "${PRETTY_CH}" \
      '\e[0;35m • %s\e[m' || true

      print_success_fail 0
    fi

    EP_I=$(( $EP_I + 1 ))
  done
}

# Let the user know the project has finished running.
function confirm_process_completed {
  patch_with_char \
  "Installation Process" \
  "${PRETTY_CH}" \
  '\e[0;105m\e[1;36m • %s\e[m' || true

  printf '\e[0;105m\e[1;36m%s\e[m\n' "COMPLETED"
}

# Entry point.
function install {
  # Call all of our functions, contingent upon the previous success code.

  # Run network test before performing request(s).
  is_internet_accessible

  # APK UPDATE
  [ $? -eq 0 ] && apk_install --update || true

  # APK UPGRADE
  [ $? -eq 0 ] && apk_install --upgrade || true

  # GAWK
  [ $? -eq 0 ] && apk_install gawk || true
  [ $? -eq 0 ] && \
  verify_install gawk \
  $( \
    gawk \
    --help 2>&1 | \
    tr -d '\n' | \
    awk '/POSIX or GNU/ { print $2 }' \
  ) || true
  [ $? -eq 0 ] && export GAWK_ONBOARD=1 || true

  # PYTHON
  [ $? -eq 0 ] && apk_install python3 /usr/bin/python3 /usr/bin/python || true
  [ $? -eq 0 ] && \
  verify_install python \
  $( \
    python \
    --version | \
    awk '/Python/ { print $1 }' \
  ) || true

  # FFMPEG
  [ $? -eq 0 ] && apk_install ffmpeg || true
  [ $? -eq 0 ] && \
  verify_install ffmpeg \
  $( \
    ffmpeg 2>&1 | \
    tr -d '\n' | \
    awk '/ffmpeg/ { print $1 }' \
  ) || true

  # WGET
  [ $? -eq 0 ] && apk_install wget || true
  [ $? -eq 0 ] && \
  verify_install wget \
  $( \
    wget --version 2>&1 | \
    awk '/GNU Wget/ { print $2 }' \
  ) || true

  # YOUTUBE-DL
  [ $? -eq 0 ] && install_youtube_dl || true
  [ $? -eq 0 ] && \
  verify_install youtube-dl \
  $( \
    youtube-dl 2>&1 | \
    tr -d '\n' | \
    awk '{ print $2 }' \
  ) || true

  # Setup the default boilerplate.
  [ $? -eq 0 ] && build_episode_list || true
  [ $? -eq 0 ] && format_episode_list || true
  [ $? -eq 0 ] && export_episode_env_vars || true
  [ $? -eq 0 ] && download_and_process_episodes || true
  [ $? -eq 0 ] && confirm_process_completed || true
}

# Call the installation function.
install