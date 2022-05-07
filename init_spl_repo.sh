#!/bin/sh

# TODO: fully comment the source below.

function generate_license () {
  local gl_ch_arg= # copyright_holder
  local gl_pn_arg= # project_name
  local gl_ls_arg= # licenses

  # Use a boolean to track whether we are reading from the JSON object
  # that contains the field/value pair "path": "templates".
  local templates_object="false"

  # Parse the SHA path to the license templates from the public GitHub API.
  # We do this by:
  #   - Requesting the root of the tree on `master` via `curl`.
  #   - Prettifying response into multi-line JSON using `jq`.
  #   - Parsing each line for "url": "<api_path>" in an `awk` program.
  #   - Printing each <api_path> encountered (the one we want is last).
  #   - Assigning the printed output from `awk` into the `templates_url` local.
  local templates_url=$( \
    curl \
    --silent \
    --request GET \
    --header 'Content-Type: application/json' \
    https://api.github.com/repos/licenses/license-templates/git/trees/master | \
    jq | awk 'BEGIN {
      fv_pat1="(\")([path]{4})(\": \")([templates]{9})(\"[,]{0,1})"
      fv_pat2="(\")([url]{3})(\": \")(.*)(\"[,]{0,1})"
    }
    $0 ~ fv_pat1 {
      path=$2
    }
    $0 ~ fv_pat2 {
      if (path!="") url=$2;
    }
    END {
      if (url!="") print url;
    }' | \
    sed 's|["]\{1\}\(.*\)["]\{1\}[,]\{0,1\}|\1|' \
  )

  if [ -z "${templates_url}" ]; then
    printf '%-8s%-2s\n' \
    "ERROR:" "No url returned from templates folder." \
    " " "GitHub API rate limit exceeded or connection lost." \
    " " "Please check your network and try again later."
    return 1
  fi

  local license_data=$( \
    curl \
    --silent \
    --request GET \
    --header 'Content-Type: application/json' \
    ${templates_url} | jq | awk 'function print_data(arr, i) {
      for(i in arr) {
        print i" "arr[i]" "
      }
    }

    BEGIN {
      fv_pat1="(\")([path]{4})(\": \")([a-zA-Z0-9_-]{3,})([.txt]{4})(\"[,]{0,1})"
      fv_pat2="(\")([url]{3})(\": \")(.*)(\"[,]{0,1})"
      idx=0
    }
    $0 ~ fv_pat1 {
      license=$2
    }
    $0 ~ fv_pat2 {
      if (license!="") url=$2;
    }
    {
      data[license]=url
    }
    END {
      print_data(data)
    }' | \
    sed 's|[\.txt]\{4\}||g; s|[", "]\{4\}| |g; s|["]\{1\}||g;' \
  )

  for arg in "$@"; do
    if [[ ! -z "$( echo "${arg}" | grep 'copyright-holder' )" ]]; then
      gl_ch_arg="$( \
        echo "${arg}" | \
        cut -d '=' -f 2 | \
        sed 's|[ ]\{1\}|\\&|g; s|[\\]\{2,\}||g;' \
      )"
    fi

    if [[ ! -z "$( echo "${arg}" | grep 'project-name' )" ]]; then
      gl_pn_arg="$( \
        echo "${arg}" | \
        cut -d '=' -f 2 | \
        sed 's|[ ]\{1\}|\\&|g; s|[\\]\{2,\}||g;' \
      )"
    fi

    if [[ ! -z "$( echo "${arg}" | grep 'licenses' )" ]]; then
      gl_ls_arg="$(
        echo "${arg}" | \
        cut -d '=' -f 2 | \
        sed 's|["]\{1\}||g' | \
        tr ',' ' ' \
      )"
    fi
  done

  if [ -z "${gl_ch_arg}" ] || \
  [ -z "${gl_pn_arg}" ] || \
  [ -z "${gl_ls_arg}" ]; then
    printf '%-8s%-2s\n' \
    "Usage:" "./init_spl_repo.sh \\" \
    " " "--copyright-holder=\"Holder's Name\" \\" \
    " " "--project-name=\"Project Name\" \\" \
    " " "--licenses=\"comma,separated,list\" [\\]" \
    " " "[--gitignore=\"SPL\"]"

    printf '\n%s\n\n' \
    "Available License / License Header Types:"
    
    printf '%-24s%-2s\n' ${license_data} | sort | awk '{ print "        " $1 }'

    echo ""

    fetch_gitignore_template
    return 0
  fi

  local license_template=
  local match_found="false"

  for match_license in $license_data; do
    if [ "${match_license}" = "${gl_ls_arg}" ]; then
      [ "${match_found}" = "false" ] && match_found="true"
    fi

    if [ "${match_found}" = "true" ] && \
    [ "${match_license}" != "${gl_ls_arg}" ]; then
      license_template=$( \
        curl \
        --silent \
        --request GET \
        --header 'Content-Type: application/json' \
        ${match_license} | jq | awk 'BEGIN {
          fv_pat="(\")([content]{7})(\": \")(.*)(\"[,]{0,1})"
        }
        $0 ~ fv_pat {
          result=$2
        }
        END {
          print result
        }' | \
        sed 's|\\n||g; s|^["]\{1\}\(.*\)["]\{1\}[,]\{0,1\}$|\1|;' | \
        base64 -d \
      )
      match_found="false"
      break
    fi
  done

  if [ ! -d LICENSES ]; then
    mkdir LICENSES
  fi

  echo "${license_template}" | \
  sed 's|[{]\{2\}[ ]\{1\}[project]\{7\}[ ]\{1\}[}]\{2\}|'"${gl_pn_arg}"'|g' | \
  sed 's|[{]\{2\}[ ]\{1\}[year]\{4\}[ ]\{1\}[}]\{2\}|'"$( date '+%Y' )"'|g' | \
  sed 's|[{]\{2\}[ ]\{1\}[organizt]\{12\}[ ]\{1\}[}]\{2\}|'"${gl_ch_arg}"'|g' > LICENSES/LICENSE-"$( \
    echo "${gl_ls_arg}" | \
    tr '[:lower:]' '[:upper:]' \
  )"
}

function init_spl_readme {
  if [ -f "$(pwd)/LICENSES/LICENSE-APACHE" ] && \
  [ -f "$(pwd)/LICENSES/LICENSE-MIT" ]; then
    if [ -f "README.md" ]; then
      rm -f README.md
    fi

    printf '%s\n' \
    "## License" \
    "" \
    "Licensed under either of" \
    "" \
    "- Apache License, Version 2.0, ([LICENSE_APACHE](LICENSES/LICENSE-APACHE) or https://www.apache.org/licenses/LICENSE-2.0)" \
    "- MIT License ([LICENSE-MIT](LICENSES/LICENSE-MIT) or https://opensource.org/licenses/MIT)" \
    "" \
    "at your option." > README.md
  else
    printf '%-8s%-2s\n' \
    "ERROR:" "Something went wrong while generating licenses!"
    return 1
  fi
}

function fetch_gitignore_template {
  local fgit_git_arg=
  local spl=

  for arg in "$@"; do
    if [[ ! -z "$( echo "${arg}" | grep 'gitignore' )" ]]; then
      fgit_git_arg="$(
        echo "${arg}" | \
        cut -d '=' -f 2 | \
        sed 's|["]\{1\}||g' \
      )"
    fi
  done

  case $( echo "${fgit_git_arg}" | tr '[:upper:]' '[:lower:]' ) in
    ada)
      spl="Ada"
      ;;
    c)
      spl="C"
      ;;
    c++|cpp|cxx|cc)
      spl="C++"
      ;;
    d)
      spl="D"
      ;;
    golang|go)
      spl="Go"
      ;;
    nim)
      spl="Nim"
      ;;
    rust|rs)
      spl="Rust"
      ;;
    swift|sw)
      spl="Swift"
      ;;
    *)
      printf '%-8s%-2s\n' \
      "Option:" "./init_spl_repo.sh \\" \
      " " "... [\\]" \
      " " "[--gitignore=\"SPL\"]"

      printf '\n%s\n\n' \
      "Gitignore Support for System Programming Languages (SPLs) - Optional"

      printf '%-8s%-2s\n' \
      " " "Ada" \
      " " "C" \
      " " "C++" \
      " " "D" \
      " " "Go" \
      " " "Nim" \
      " " "Rust" \
      " " "Swift"

      return 0
      ;;
  esac

  curl \
    --silent \
    --request GET \
    --header 'Content-Type: text/html' \
    "https://raw.githubusercontent.com/github/gitignore/main/${spl}.gitignore" > .gitignore
}

function add_commit_push_spl_repo_init {
  git add LICENSES README.md
  [ -f .gitignore ] && git add .gitignore
  git commit -m "Initialized repo."
  git push --set-upstream origin $( git config --get init.defaultBranch )
}

function init_spl_repo {
  local isr_ch_arg= # copyright_holder
  local isr_pn_arg= # project_name
  local isr_ls_arg= # licenses
  local isr_gi_arg= # gitignore

  for arg in "$@"; do
    if [[ ! -z "$( echo "${arg}" | grep 'copyright-holder' )" ]]; then
      isr_ch_arg="$( \
        echo "${arg}" | \
        cut -d '=' -f 2 | \
        sed 's|[ ]\{1\}|\\&|g;' \
      )"
    fi

    if [[ ! -z "$( echo "${arg}" | grep 'project-name' )" ]]; then
      isr_pn_arg="$( \
        echo "${arg}" | \
        cut -d '=' -f 2 | \
        sed 's|[ ]\{1\}|\\&|g;' \
      )"
    fi

    if [[ ! -z "$( echo "${arg}" | grep 'licenses' )" ]]; then
      isr_ls_arg="$(
        echo "${arg}" | \
        cut -d '=' -f 2 | \
        sed 's|["]\{1\}||g' | \
        tr ',' ' ' \
      )"
    fi

    if [[ ! -z "$( echo "${arg}" | grep 'gitignore' )" ]]; then
      isr_gi_arg="$( \
        echo "${arg}" | \
        cut -d '=' -f 2 | \
        sed 's|["]\{1\}||g' \
      )"
    fi
  done

  if [ -z "${isr_ch_arg}" ] || \
  [ -z "${isr_pn_arg}" ] || \
  [ -z "${isr_ls_arg}" ]; then
    # Show error message (no args passed).
    generate_license
    return 0
  fi

  for license in $isr_ls_arg; do
    generate_license \
    --copyright-holder="${isr_ch_arg}" \
    --project-name="${isr_pn_arg}" \
    --licenses="${license}"
  done

  init_spl_readme
  if [ $? -eq 0 ] && [[ ! -z "${isr_gi_arg}" ]]; then
    fetch_gitignore_template --gitignore="${isr_gi_arg}"
  fi
  [ $? -eq 0 ] && add_commit_push_spl_repo_init
}

init_spl_repo "$@"