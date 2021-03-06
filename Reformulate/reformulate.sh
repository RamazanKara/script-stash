#!/bin/bash
# reformulate.sh
# Author: Vedant Puri
# Version: 2.0.1

# ----- ENVIRONMENT & CONSOLE

# Console text preferences
underline="$(tput smul)"
bold="$(tput bold)"
normal="$(tput sgr0)"

# Script information
script_version="2.0.1"

# Environment information with defaults
output="/dev/stdout"
given_project_path="$(pwd)/"
git_repo=""
formula_file=""
current_tag_name=""
latest_tag_name=""
retrieved_sha256=""
temp_dir="updater_temp/"
commit=false


# ----- SCRIPT SUPPORT

# Print the script version to console
print_version() {
  echo "${script_version}"
}

# Print reformulate.sh usage
print_usage() {
  echo "Usage: ${bold}./reformulate.sh${normal} [-v|--version] [-h|--help] [-ff=|-formula-file=] [-c|-commit]
  where:
  ${underline}-v${normal}        Prints script version
  ${underline}-h${normal}        Prints script usage
  ${underline}-ff=${normal}      Updates the specified formula file
  ${underline}-c${normal}        Automatically commit changes to master branch"
}


# ----- REFORMULATE PROJECT MANAGEMENT

# Extract info about repository
extract_information() {
  if [[ -z "${formula_file}" ]]
  then
    echo "No formula file provided." && exit
  fi
  echo "${bold}Extracting relevant information...${normal}"
  local git_config_file="${given_project_path}.git/config"
  if [[ ! -f "${git_config_file}" ]]
  then
    echo "Not a git repo" && exit
  fi
  local url="$(awk '/url/{print  $2}' "${given_project_path}${formula_file}" | cut -f4- -d/)"
  git_repo="$(echo ${url} | cut -d '/' -f 1,2)"
  echo "Extraction complete."

}

# Retreive name of latest release
get_latest_tag() {
  echo "${bold}Retrieving latest release name...${normal}"
  latest_tag_name="$(curl -s https://api.github.com/repos/"${git_repo}"/releases/latest |  sed -n 's|.*"tag_name": "\(.*\)",|\1|p')"
  if [[ -z "${latest_tag_name}" ]]
  then
    echo "No releases exist for ${git_repo}."
    exit
  fi
  current_tag_name="$(awk '/version/{print $NF}' ${formula_file})"
  if [[ ! -z "${current_tag_name}" && "${current_tag_name}" == "\"${latest_tag_name}\"" ]]
  then
    echo "No new release detected. Formula up-to-date" && exit
  fi
  echo "Tag name ${latest_tag_name} retreived."
}

# Generate sha256 of latest release file
retreive_sha256() {
  echo "${bold}Generating file hash${normal}"
  mkdir -p "${temp_dir}"
  $(wget -q  https://github.com/"${git_repo}"/archive/"${latest_tag_name}".tar.gz -P "${temp_dir}")
  local sha256_output="$(shasum -a 256 "${temp_dir}${latest_tag_name}".tar.gz)"
  retrieved_sha256="$(echo ${sha256_output} | cut -d " " -f1)"
  rm -r "${temp_dir}"
  echo "Hash successfully generated."
}

# Update relevant information in the formula file
update_formula() {
  echo "${bold}Updating Formula file...${normal}"
  local new_url="https://github.com/${git_repo}/archive/${latest_tag_name}.tar.gz"
  $(sed -i '' "s|.*url.*|  url \"${new_url}\"|"  "${formula_file}")
  $(sed -i '' "s|.*version.*|  version \"${latest_tag_name}\"|"  "${formula_file}")
  $(sed -i '' "s|.*sha256.*|  sha256 \"${retrieved_sha256}\"|"  "${formula_file}")
  echo "Update complete."
}

commit_changes() {
  if [[ "${commit}" == "true" ]]
  then
    echo "${bold}Comitting changes...${normal}"
    git add "$formula_file"
    git commit -m "Update formula for \"${git_repo}\" to ${latest_tag_name}"
    git push origin master
    echo "Changes pushed to GitHub."
  fi
}

# ----- REFORMULATE CONTROL FLOW

# Parse script arguments
parse_args() {
  [[ -z  "${@}" ]] && echo "Invalid argument. Run with ${underline}-h${normal} for help." && exit
  for arg in "${@}"
  do
    case "${arg}" in
      -v|--version)
      print_version
      ;;
      -h|--help)
      print_usage
      ;;
      -ff=*|--formula-file=*)
      local formula_path="${arg#*=}"
      [[ -z "${formula_path}" ]] && echo "No formula file provided. Quitting..." && exit
      formula_file="${formula_path}"
      ;;
      -c|--commit)
      commit=true
      ;;
      *)
      echo "Invalid argument. Run with ${underline}-h${normal} for help." && exit
      ;;
    esac
  done
}

# Script Execution
parse_args "${@}"
extract_information
get_latest_tag
retreive_sha256
update_formula
commit_changes
