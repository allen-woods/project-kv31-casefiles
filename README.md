# ✨ System Programming Language Template Repo

When developing a project that uses a system programming language (SPL), it is common practice to provide both an Apache 2.0 license and an MIT license on an open-source repository.

Currently, there is no facility for adding multiple licenses to a repository using GitHub's `gh` CLI utility.

This repository is an example of how we can use the `--template` flag provided by `gh` in combination with shell script to achieve the desired result.

You can see the resulting output of this template repo here:

👉 [SPL Template Repo Sample](https://github.com/allen-woods/spl-template-repo-sample)

## ✅ Compatible Languages

As of the date of the latest commit to this repo, the appropriate languages to use with this template repository are as follows:

### 🧑‍🔬 Supported SPLs

| Language | Gitignore String | SPL args                        |
| :------- | :--------------- | :------------------------------ |
| Ada      | "Ada"            | "ada"                           |
| C        | "C"              | "c"                             |
| C++      | "C++"            | "c++"<br>"cpp"<br>"cxx"<br>"cc" |
| D        | "D"              | "d"                             |
| Go       | "Go"             | "go"<br>"golang"                |
| Nim      | "Nim"            | "nim"                           |
| Rust     | "Rust"           | "rust"<br>"rs"                  |
| Swift    | "Swift"          | "swift"<br>"sw"                 |

Source: [System programming language](https://en.wikipedia.org/wiki/System_programming_language) - Wikipedia

## 🧸 Basic Installation

At minimum, run the following locally from your work $PATH:

```shell
# Simple setup.

gh repo create <new_repo_name> \
  --clone
  --template "allen-woods/spl-template-repo"
```

Once the repository has been cloned locally, `cd` into it and run the script:

```shell
chmod +x ./init_spl_repo.sh
./init_spl_repo.sh
```

You will be presented with a usage message detailing how to run the script successfully&mdash;see [here](https://github.com/allen-woods/spl-template-repo#-sample-script-usage-message) for an example.

### 🔍 Example SPL Project Script Flags

```shell
./init_spl_repo.sh \
  --copyright-holder="Your Name" \
  --project-name="Project Name" \
  --licenses="apache,mit"
```

### 📖 Script Outline

GitHub does provide a short path to an official list of licenses that does not include any software distribution header files. However, for the sake of flexibility and user preference, the script in this repo takes a more thorough approach to fetching its data and makes all license-related files available.

This script automatically performs the following steps:

1. Request root of `licenses/license-templates` from `api.github.com` via `curl`.
   - a. Output `JSON` in multi-line format using `jq`.
   - b. Iterate over field/value pairs using `awk`.
   - c. Parse `templates` string value contained in the `path` field to locate `JSON` obect.
   - d. Parse tree `https` address value contained in the `url` field.
2. Request tree given by `http` address parsed in **1a**.
   - a. Same as **1a**.
   - b. Same as **1b**.
   - c. Parse basename values of licenses contained in the `path` fields of their `JSON` objects.
   - d. Parse blob `https` address values contained in the `url` fields of license `JSON` objects.
   - e. Map each given basename to its corresponding `https` address.
3. Iterate across mapped basenames until user requested license is found.
4. Request blob given by corresponding `https` address.
   - a. Same as **1a**.
   - b. Same as **1b**.
   - c. Parse and decode `base64` encoded string contained in the `content` field.
   - d. Interpolate incoming arguments and `date` information into the decoded license body.
   - e. Echo the license to a persisted file under a newly created `LICENSES` folder.
5. Check for the presence of an `apache` and an `mit` license.
   - a. Conditionally remove any pre-existing `README.md` file, if one is found.
   - b. Conditionally generate a `README.md` file containing a dual-license **License** clause.
6. Use the `gitignore` argument's value to request a file from `raw.githubusercontent.com`.
   - a. Persist the gitignore file to the root path of the repo.
7. Process the files with `git`.
   - a. Add the created files (`git add`).
   - b. Commit the files with message `Initialized repo.`
   - c. Push the commit using the `--set-upstream` flag.
   - d. Upstream automatically conforms to `init.defaultBranch`.

### 🎉 Next Steps

From here, you can:

- Delete `init_spl_repo.sh` from your local repo directory.
- Add information relevant to your project above the **License** header in the README.

## ⚡️ Advanced Installation

GitHub provides `.gitignore` templates for many SPLs, but the `gh` CLI utility currently does not allow mixed use of both the `--gitignore` and `--template` flags.

To enable the `.gitignore` template for the supported languages in [Table 1.1](#supported-spls) above, we can simply provide the gitignore type via the optional `--gitignore` flag, as follows:

```shell
# Consult table 1.1 for supported SPLs.

gh repo create <new_repo_name> \
  --clone \
  --description="Your description here." \
  --public \
  --template "allen-woods/spl-template-repo"

cd <new_repo_name>

./init_spl_repo.sh \
  --copyright-holder="Your Name" \
  --project-name="Project Namr" \
  --licenses="apache,mit" \
  --gitignore="rs" # Let's use Rust!
```

## 🔬 Sample Script Usage Message

```
Usage:  ./init_spl_repo.sh \
        --copyright-holder="Holder's Name" \
        --project-name="Project Name" \
        --licenses="comma,separated,list" [\]
        [--gitignore="SPL"]

Available License / License Header Types:

        agpl3
        agpl3-header
        apache
        apache-header
        bsd2
        bsd3
        cc0
        cc0-header
        cc_by
        cc_by-header
        cc_by_nc
        cc_by_nc-header
        cc_by_nc_nd
        cc_by_nc_nd-header
        cc_by_nc_sa
        cc_by_nc_sa-header
        cc_by_nd
        cc_by_nd-header
        cc_by_sa
        cc_by_sa-header
        cddl
        epl
        gpl2
        gpl3
        gpl3-header
        isc
        lgpl
        mit
        mpl
        mpl-header
        unlicense
        wtfpl
        wtfpl-header
        wtfpl-header-warranty
        x11
        zlib

Option: ./init_spl_repo.sh \
        ... [\]
        [--gitignore="SPL"]

Gitignore Support for System Programming Languages (SPLs) - Optional

        Ada
        C
        C++
        D
        Go
        Nim
        Rust
        Swift
```
