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
replace_group_id_raml() {
  local directory="$1"
  local org_id="$2"
  local main_file="$3"
  log "Replacing GROUP_ID in $directory/api.raml and $directory/exchange.json..."
  sed -i  '' -e "s/GROUP_ID/$org_id/g" "$directory/$main_file" || exit 1
  sed -i  '' -e "s/GROUP_ID/$org_id/g" "$directory/exchange.json" || exit 1
}

# Function to rename directories within exchange_modules
rename_exchange_modules_raml() {
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

# Function to process a raml project
process_raml() {
  local directory="$1"
  local customer_name="$2"
  local control_plane="$3"
  local type="$4"
  log "Processing $directory..."
  cd "$directory" || exit 1
  
  local ver="1.0.0"
  git_managment "$customer_name"
  # Deploy using Maven
  log "Deploying using Anypoint cli..."
  log "Creating RAML project $directory of type: $type..."
  anypoint-cli-v4 designcenter:project:create --client_id $client_application_id --client_secret $client_application_secret --organization $organization_id  --type $type $directory || exit 1
  log "Deploying using Anypoint cli..."
  log "Uploading RAML content from directory: $directory..."
  anypoint-cli-v4 designcenter:project:upload --client_id $client_application_id --client_secret $client_application_secret --organization $organization_id  $directory . || exit 1
  log "Publishing RAML project with name: $directory..."
  anypoint-cli-v4 designcenter:project:publish --client_id $client_application_id --client_secret $client_application_secret --organization $organization_id  $directory  --apiVersion 1.0 --version $ver || exit 1
  cd - || exit 1
  log "Finished processing $directory."
}

git_managment(){
  local customer_name="$1"

 # Check if the branch already exists
  if [[ "$git_management" == true ]]; then
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

}

# Function to process each directory
process_directory() {
  local directory="$1"
  local customer_name="$2"
  local control_plane="$3"
  local template="$4"
  log "Processing $directory..."
  cd "$directory" || exit 1

  git_managment "$customer_name"
  # Deploy using Maven
  log "Deploying using Maven..."
  deploy_with_maven "$control_plane" "$template"

  cd - || exit 1
  log "Finished processing $directory."
}

# Function to deploy using Maven based on control plane
deploy_with_maven() {
  local control_plane="$1"
  local template="$2"
  

  local profile_template=""
  if [[ "$control_plane" == "true" ]]; then
       log "project is a template..."
       profile_template="-Ptemplate" 
  fi
  
  local profile_us=""
  if [[ "$control_plane" == true ]]; then
    log "running on US control plane..."
    profile_us="-Pcp_us"
  else
    log "running on EU control plane..."
  fi
  
  $mvn_cmd -U --settings $script_dir/.mvn/settings.xml clean deploy $profile_template $profile_us -DskipTests || exit 1
}

# Function to read JSON file and process directories
process_directories_from_json() {
  local csv_file="$1"
  log "Reading directories from $csv_file..."

  while IFS=, read -r name type template import; do
   if [[ "$import" == "true" ]]; then
      log "Processing directory $name of type: $type..."
      case "$type" in
        "maven")
          replace_group_id "$name" "$organization_id" pom.xml
          process_directory "$name" "$customer_name" "$control_plane" "$template"
          ;;
        "raml")
            replace_group_id_raml "$name" "$organization_id" "api.raml"
            rename_exchange_modules_raml "$name" "$organization_id"
            process_raml "$name" "$customer_name" "$control_plane" "raml"
          ;;
        "raml-fragment")
            replace_group_id_raml "$name" "$organization_id" "library.raml"
            rename_exchange_modules_raml "$name" "$organization_id"
            process_raml "$name" "$customer_name" "$control_plane" "raml-fragment"
          ;;
        *)
          log "Error: Unsupported directory type."
          exit 1
          ;;
      esac
    else
       log "Skipping directory $name of type: $type..."
    fi
  done < "$csv_file"

  log "Finished processing directories."
}
# Function to display script usage
show_usage() {
  echo "Usage: $0 [-w] [-g] [-d] customer_name organization_id connected_app_id connected_app_secret"
  exit 1
}


# Main script starts here
log "Start deploy."


# Process optional flags
while getopts ":wgd" opt; do
  case $opt in
    w)
      use_wrapper=true
      ;;
    g)
      git_management=true
      ;;
    d)
      control_plane=true
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
log "use_wrapper: $use_wrapper"
log "git_management: $git_management"
log "control_plane: $control_plane"

customer_name=$1
organization_id=$2
client_application_id=$3
client_application_secret=$4
script_dir=$(pwd)

#export variables
export MULE_CONNECTED_APP_CLIENT_ID=$client_application_id
export MULE_CONNECTED_APP_CLIENT_SECRET=$client_application_secret
export MULE_ORG_ID=$organization_id

# versions
java_version="1.8"
maven_version="3.9.0"
anypoint_cli_version="1.0.0"


if [[ "$control_plane" != true ]]; then
    log "using Anypoint CLI on EU control plane..."
    export ANYPOINT_HOST=eu1.anypoint.mulesoft.com
else
    log "using Anypoint CLI on US control plane..."
fi

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
