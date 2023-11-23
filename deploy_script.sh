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
  log "Replacing GROUP_ID in $directory/pom.xml..."
  sed -i "s/GROUP_ID/$org_id/g" "$directory/pom.xml"
}

# Function to replace GROUP_ID placeholder in api.raml and exchange.json
replace_group_id_additional() {
  local directory="$1"
  local org_id="$2"
  log "Replacing GROUP_ID in $directory/api.raml and $directory/exchange.json..."
  sed -i "s/GROUP_ID/$org_id/g" "$directory/api.raml"
  sed -i "s/GROUP_ID/$org_id/g" "$directory/exchange.json"
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

  # Create a local git branch
  log "Creating local git branch customer/$customer_name..."
  git checkout -b "customer/$customer_name" || exit 1

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
  if [[ "$control_plane" == "eu" ]]; then
    $mvn_cmd clean deploy
  else
    $mvn_cmd clean deploy -Pcp_us
  fi
}

# Function to read JSON file and process directories
process_directories_from_json() {
  local json_file="$1"
  log "Reading directories from $json_file..."

  while IFS= read -r line; do
    local name=$(echo "$line" | jq -r '.name')
    local type=$(echo "$line" | jq -r '.type')

    case "$type" in
      "maven")
        replace_group_id "$name" "$organization_id"
        process_directory "$name" "$customer_name" "$control_plane"
        ;;
      "raml-api")
        replace_group_id_additional "$name" "$organization_id"
        rename_exchange_modules "$name" "$organization_id"
        process_directory "$name" "$customer_name" "$control_plane"
        anypoint-cli-v4 designcenter:project:create --client_id $client_application_id --client_secret $client_application_secret --organization $organization_id  --type raml "$name" 
        ;;
      "raml-fragment")
        replace_group_id_additional "$name" "$organization_id"
        rename_exchange_modules "$name" "$organization_id"
        process_directory "$name" "$customer_name" "$control_plane"
        anypoint-cli-v4 designcenter:project:create --client_id $client_application_id --client_secret $client_application_secret --organization $organization_id --type raml_fragment "$name" 
        ;;
      *)
        log "Error: Unsupported directory type."
        exit 1
        ;;
    esac
  done < <(jq -c '.directories[]' "$json_file")

  log "Finished processing directories."
}

# Main script starts here
control_plane=$1
customer_name=$2
organization_id=$3
client_application_id=$4
client_application_secret=$5

#check if jq is available in the environment
which jq
if [[ $? != 0 ]]; then
  log "jq utility is not installed."
  exit 1
fi

# Read Java and Maven versions from JSON file

java_version=$(jq -r '.java_version' "deploy_config.json")
maven_version=$(jq -r '.maven_version' "deploy_config.json")
maven_wrapper=$(jq -r '.maven_wrapper' "deploy_config.json")
anypoint_cli_version=$(jq -r '.anypoint_cli_version' "deploy_config.json")

if [[ "$maven_wrapper" != "true" ]]; then
   $mvn_cmd="./mvnw"
  else
   $mvn_cmd="mvn"
  fi

# Check Java and Maven versions
check_anypoint_cli_version
check_java_version
check_maven_version


# Process directories from JSON file
process_directories_from_json "deploy_config.json"
