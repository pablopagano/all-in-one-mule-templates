#!/bin/bash
# Function to log messages
log() {
  local message="$1"
  echo "$(date +"%Y-%m-%d %H:%M:%S"): $message"
}

# Function to check if a command is available
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Function to check Java version
check_java_version() {
  log "Checking Java version..."
  local version=$(java -version 2>&1 | awk -F '"' '/version/ {print $2}')
  if [[ "$version" < "$java_version" ]]; then
    log "Error: Java version $java_version or higher is required."
    exit 1
  fi
  log "Java version is $version."
}

# Function to check Maven version
check_maven_version() {
  log "Checking Maven version..."
  local version=$($mvn_cmd -v | awk -F ' ' '/Apache Maven/ {print $3}')
  if [[ "$version" < "$maven_version" ]]; then
    log "Error: Maven version $maven_version or higher is required."
    exit 1
  fi
  log "Maven version is $version."
}

# Function to check anypoint cli version
check_anypoint_cli_version() {
  log "Checking anypoint cli version..."
  local version=$(anypoint-cli-v4 --version | awk -F'/' '{print $2}')
  if [[ "$version" < "$anypoint_cli_version" ]]; then
    log "Error: Maven version $anypoint_cli_version or higher is required."
    exit 1
  fi
  log "Anypoint cli version is $version."
}


# Function to replace GROUP_ID placeholder in pom.xml
replace_group_id() {
  local directory="$1"
  local org_id="$2"
  local file="$3"
  log "Replacing GROUP_ID in $directory/$file..."
  sed -i '' -e "s/GROUP_ID/$org_id/g" "$directory/$file" || exit 1
}

# Function to replace GROUP_ID placeholder in api.raml and exchange.json
replace_group_id_additional() {
  local directory="$1"
  local org_id="$2"
  log "Replacing GROUP_ID in $directory/api.raml and $directory/exchange.json..."
  sed -i "s/GROUP_ID/$org_id/g" "$directory/api.raml" || exit 1
  sed -i "s/GROUP_ID/$org_id/g" "$directory/exchange.json" || exit 1
}

# Function to rename directories within exchange_modules
rename_exchange_modules() {
  local directory="$1"
  local org_id="$2"
  local exchange_modules="$directory/exchange_modules"

  if [ -d "$exchange_modules" ]; then
    log "Renaming directories within $exchange_modules..."
    for subdirectory in "$exchange_modules"/*; do
      local subdirectory_name=$(basename "$subdirectory")
      local new_name="$exchange_modules/$org_id"
      mv "$subdirectory" "$new_name"
      log "Renamed $subdirectory_name to $org_id."
    done
  fi
}

# Function to process each directory
process_directory() {
  local directory="$1"
  local customer_name="$2"
  local control_plane="$3"
  log "Processing $directory..."
  cd "$directory" || exit 1

  # Check if the branch already exists
  if [[ "$skip_git" == true ]]; then
    if ! git rev-parse --verify "customer/$customer_name" >/dev/null 2>&1; then
      log "Branch customer/$customer_name does not exist. Creating it..."
      git checkout -b "customer/$customer_name" || exit 1
    else
      log "Branch customer/$customer_name already exists. Using it..."
      git checkout "customer/$customer_name" || exit 1
    fi
  else
    log "skipping git managment"
  fi

  # Deploy using Maven
  log "Deploying using Maven..."
  deploy_with_maven "$directory" "$control_plane"

  cd - || exit 1
  log "Finished processing $directory."
}

# Function to deploy using Maven based on control plane
deploy_with_maven() {
  local directory="$1"
  local control_plane="$2"

  if [ -n "$tag_version" ]; then
      log "using a new tag for deployment: $tag_version..."
      $mvn_cmd -U versions:set -DnewVersion=$tag_version || exit 1
  fi

  if [[ "$control_plane" == true ]]; then
    log "running on us control plane..."
    $mvn_cmd -U --settings $script_dir/.mvn/settings.xml clean deploy -Pcp_us -DskipTests || exit 1
  else
    log "running on eu control plane..."
    $mvn_cmd -U --settings $script_dir/.mvn/settings.xml clean deploy  -DskipTests || exit 1
  fi
}

# Function to read JSON file and process directories
process_directories_from_json() {
  local csv_file="$1"
  log "Reading directories from $json_file..."

  while IFS=, read -r name type; do
    log "Processing directory $name of type: $type..."
    case "$type" in
      "maven")
        replace_group_id "$name" "$organization_id" pom.xml
        process_directory "$name" "$customer_name" "$control_plane"
        ;;
      "raml-api")
        if [[ "$skip_design_center" == true ]]; then
          replace_group_id_additional "$name" "$organization_id"
          rename_exchange_modules "$name" "$organization_id"
          process_directory "$name" "$customer_name" "$control_plane"
          anypoint-cli-v4 designcenter:project:create --client_id $client_application_id --client_secret $client_application_secret --organization $organization_id  --type raml "$name" 
          else
            log "skipping design center project..."
        fi
        ;;
      "raml-fragment")
        if [[ "$skip_design_center" == true ]]; then
          replace_group_id_additional "$name" "$organization_id"
          rename_exchange_modules "$name" "$organization_id"
          process_directory "$name" "$customer_name" "$control_plane"
          anypoint-cli-v4 designcenter:project:create --client_id $client_application_id --client_secret $client_application_secret --organization $organization_id --type raml_fragment "$name" 
        else
            log "skipping design center project..."
        fi
         ;;
      *)
        log "Error: Unsupported directory type."
        exit 1
        ;;
    esac
  done < "$csv_file"

  log "Finished processing directories."
}
# Function to display script usage
show_usage() {
  echo "Usage: $0 [-t tag_version] [-w] [-g] [-d] [-c] customer_name organization_id connected_app_id connected_app_secret"
  exit 1
}


# Main script starts here
log "Start deploy."


# Process optional flags
while getopts ":t:w:g:d:c" opt; do
  case $opt in
    t)
      tag_version=$OPTARG
      ;;
    w)
      use_wrapper=true
      ;;
    g)
      skip_git=true
      ;;
    d)
      control_plane=true
      ;;
    c)
      skip_design_center=true
      ;;
    \?)
      echo "Invalid option: -$OPTARG"
      show_usage
      ;;
    :)
      echo "Option -$OPTARG requires an argument."
      show_usage
      ;;
  esac
done

# Shift the processed options out of the positional parameters
shift $((OPTIND-1))

# Check for the required positional parameters
if [ "$#" -ne 4 ]; then
  show_usage
fi


customer_name=$1
organization_id=$2
client_application_id=$3
client_application_secret=$4
script_dir=$(pwd)

#export variables
export MULE_CONNECTED_APP_CLIENT_ID=$client_application_id
export MULE_CONNECTED_APP_CLIENT_SECRET=$client_application_secret

# versions
java_version="1.8"
maven_version="3.9.5"
anypoint_cli_version="1.0.0"

if [[ "$use_wrapper" == true ]]; then
   log "Use maven wrapper."
   mvn_cmd="$script_dir/mvnw"
  else
   log "Use Environment Maven."
   mvn_cmd="mvn"
fi

replace_group_id ".mvn" "$organization_id" settings.xml

# Check Java and Maven versions
check_anypoint_cli_version
check_java_version
check_maven_version


# Process directories from JSON file
process_directories_from_json "deploy_config.csv"
