#!/usr/bin/env bash

####
# Copyright (c) 2024 Kong, Inc.
# Copyright (c) 2016-2021 Jakob Westhoff <jakob@westhoffswelt.de>
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
#  - Redistributions of source code must retain the above copyright notice, this
#    list of conditions and the following disclaimer.
#  - Redistributions in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the documentation
#    and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUsed AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVIsed OF THE POSSIBILITY OF SUCH DAMAGE.
####

KLCR_VERSION="2.0"

_prettytable_char_top_left="┌"
_prettytable_char_horizontal="─"
_prettytable_char_vertical="│"
_prettytable_char_bottom_left="└"
_prettytable_char_bottom_right="┘"
_prettytable_char_top_right="┐"
_prettytable_char_vertical_horizontal_left="├"
_prettytable_char_vertical_horizontal_right="┤"
_prettytable_char_vertical_horizontal_top="┬"
_prettytable_char_vertical_horizontal_bottom="┴"
_prettytable_char_vertical_horizontal="┼"

# Escape codes

# Default colors
_prettytable_color_blue="0;34"
_prettytable_color_green="0;32"
_prettytable_color_cyan="0;36"
_prettytable_color_red="0;31"
_prettytable_color_purple="0;35"
_prettytable_color_yellow="0;33"
_prettytable_color_gray="1;30"
_prettytable_color_light_blue="1;34"
_prettytable_color_light_green="1;32"
_prettytable_color_light_cyan="1;36"
_prettytable_color_light_red="1;31"
_prettytable_color_light_purple="1;35"
_prettytable_color_light_yellow="1;33"
_prettytable_color_light_gray="0;37"

# Somewhat special colors
_prettytable_color_black="0;30"
_prettytable_color_white="1;37"
_prettytable_color_none="0"

function _prettytable_prettify_lines() {
    cat - | sed -e "s@^@${_prettytable_char_vertical}@;s@\$@	@;s@	@	${_prettytable_char_vertical}@g"
}

function _prettytable_fix_border_lines() {
    cat - | sed -e "1s@ @${_prettytable_char_horizontal}@g;3s@ @${_prettytable_char_horizontal}@g;\$s@ @${_prettytable_char_horizontal}@g"
}

function _prettytable_colorize_lines() {
    local color="$1"
    local range="$2"
    local ansicolor="$(eval "echo \${_prettytable_color_${color}}")"

    cat - | sed -e "${range}s@\\([^${_prettytable_char_vertical}]\\{1,\\}\\)@"$'\E'"[${ansicolor}m\1"$'\E'"[${_prettytable_color_none}m@g"
}

function prettytable() {
    local cols="${1}"
    local color="${2:-none}"
    local input="$(cat -)"
    local header="$(echo -e "${input}"| head -n1)"
    local body=$(echo -e "${input}" | tail -n+2)
    {
        # Top border
        echo -n "${_prettytable_char_top_left}"
        for i in $(seq 2 ${cols}); do
            echo -ne "\t${_prettytable_char_vertical_horizontal_top}"
        done
        echo -e "\t${_prettytable_char_top_right}"

        # Header
        echo -e "${header}" | _prettytable_prettify_lines

        # Horizontal delimiter
        echo -n "${_prettytable_char_vertical_horizontal_left}"
        for i in $(seq 2 ${cols}); do
            echo -ne "\t${_prettytable_char_vertical_horizontal}"
        done
        echo -e "\t${_prettytable_char_vertical_horizontal_right}"

        # Body
        echo -e "${body}" | _prettytable_prettify_lines

        # Bottom border
        echo -n "${_prettytable_char_bottom_left}"
        for i in $(seq 2 ${cols}); do
            echo -ne "\t${_prettytable_char_vertical_horizontal_bottom}"
        done
        echo -e "\t${_prettytable_char_bottom_right}"

    } | column -t -s $'\t' | _prettytable_fix_border_lines | _prettytable_colorize_lines "${color}" "2"
}

function print_help() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Options:
  -i, --input-file FILE    Details of every Kong environment.
  -o, --output-dir DIR     Name of the directory where all license reports will be saved.
  -s, --suppress           Suppress printing to standard output.
  -v, --version            Shows the version of KLCR.
  -h, --help               Display this help message.

Example:
  $(basename "$0") -i input.json -o ./licenses/test

Description:
  This script analyzes Kong environments and provides a summary of services
  and workspaces. In addition, it collects the output of the license report
  for every Kong enviroment provided.
  
  It requires 'jq' to be installed. You can download it from
  https://stedolan.github.io/jq/

Disclaimr:
  KLCR is NOT a Kong product, nor is it supported by Kong.

EOF
}

function print_version() {
  cat <<EOF

Kong License Consumption Report (KLCR)
Version $KLCR_VERSION

KLCR is NOT a Kong product, nor is it supported by Kong.

EOF
}

# Generic method for hitting endpoints on the Admin API
function fetch_from_admin_api() {
  local host="$1"
  local token="$2"
  local path="$3"
  local flag=""

  if [[ -n "$4" ]]; then
    flag="$4"
  fi

  if output=$(curl -s $flag -X GET "${host}${path}" -H "Kong-Admin-Token: ${token}" -H "Content-Type: application/json"); then
    response="$output"
  else
    echo "Error: Failed to fetch ${path} from ${host}" >&2
    return 1
  fi

  echo "$response"
}

# Gets the license report 
function fetch_license_report() {
  local name="$1"
  local host="$2"
  local token="$3"
  local path="/license/report"

  echo $(fetch_from_admin_api $host $token $path) | jq -s 'add'
}

function fetch_gateway_status() {
  local host="$1"
  local token="$2"
  local path="/status"
  local flag="-I"

  status=$(fetch_from_admin_api $host $token $path $flag | head -n 1)

  # remove the trailing newline first, and then the white space
  echo "${status//[$'\t\r\n']}" | sed 's/.$//'
}

function fetch_workspaces() {
  local size=1000
  local host="$1"
  local token="$2"
  local path="/workspaces?size=$size"

  # get the first batch of $size workspaces
  local raw=$(fetch_from_admin_api $host $token $path | jq)
  local workspaces=$(echo $raw | jq -r '.data[].name')

  # we need to make sure we check all the "pages" in case there are more than 1000 workspaces,
  local offset=$(echo $raw | jq -r '.next // empty')

  # let's grab $size workspaces at a time until we run out
  while [[ -n "${offset}" ]]; do
    raw=$(fetch_from_admin_api $host $token $offset | jq)
    workspaces="$workspaces $(echo $raw | jq -r '.data[].name')"
    offset=$(echo $raw | jq -r '.next // empty')
  done  

  echo $workspaces | xargs -n1 | sort | xargs
}

# Get a list of services in the workspace
function fetch_workspace_services() {
  local size=1000
  local host="$1"
  local token="$2"
  local path="/$3/services?size=$size"

  # get the first batch of $size workspaces
  local raw=$(fetch_from_admin_api $host $token $path | jq)
  local services=$(echo $raw | jq -r '[.data[] | {service: "\(.protocol)://\(.host):\(.port)\(.path)"}]')

  # we need to make sure we check all the "pages" in case there are more than 1000 workspaces,
  local offset=$(echo $raw | jq -r '.next // empty')

  # let's grab $size workspaces at a time until we run out
  while [[ -n "${offset}" ]]; do
    raw=$(fetch_from_admin_api $host $token $offset | jq)
    nextBatch=$(echo $raw | jq -r '[.data[] | {service: "\(.protocol)://\(.host):\(.port)\(.path)"}]')
    services=$(jq --argjson arr1 "$services" --argjson arr2 "$nextBatch" -n '$arr1 + $arr2')
    offset=$(echo $raw | jq -r '.next // empty')
  done

  if [[ ! -z "$4" && ! -z "$5" ]]; then    
    services=$(echo $services | jq -r -s --arg master $4 --arg minions $5 'add | .[].service |= sub($minions;$master)')
  fi

  echo $services
}

# Get CLI options
PARAMS=""

while (( "$#" )); do
    case "$1" in
      -i|--input-file)
        if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
          INPUT_FILE=$2
          shift 2
        else
          echo "Error: Input file is missing" >&2
          exit 1
        fi
        ;;
      -o|--output-file)
        if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
          OUTPUT_DIR=$2
          shift 2
        else
          echo "Error: Output file is missing" >&2
          exit 1
        fi
        ;;
      -s|--suppress)
        NO_PRETTY_PRINT=1
        shift
        ;;
      -v|--version)
        print_version
        exit 0
        ;;        
      -h|--help)
        print_help
        exit 0
        ;;
      -*)   # unsupported flags
        echo "Error: Unsupported flag $1" >&2
        exit 2
        ;;
      *) # preserve positional arguments
        PARAMS="$PARAMS $1"
        shift
        ;;
    esac
done

# set positional arguments in their proper place
eval set -- "$PARAMS"

# Check if jq is available
if ! command -v jq &> /dev/null; then
    echo "Error: 'jq' is not installed or not available in the PATH."
    echo "Please install 'jq' to proceed. You can download it from https://stedolan.github.io/jq/."
    exit 1
fi

if [[ -z "$INPUT_FILE" ]]; then
    echo "Input file is missing. Please specify one with the --input-file (-i) option."
    exit 1
fi

if [[ -z "$OUTPUT_DIR" ]]; then
    echo "Output directory is missing. Please specify one with the --ouput-dir (-o) option."
    exit 1
fi

# Create the OUTPUT_DIR if it doesn't exist
if [ ! -d "$OUTPUT_DIR" ]; then
  mkdir "$OUTPUT_DIR"
fi 

printf "\n";

ENV_COUNT=$(jq -r '.environments | length' $INPUT_FILE)
MASTER=$(jq -r '.discrete.master' $INPUT_FILE)
MINIONS=$(jq -r '.discrete.minions' $INPUT_FILE)

# Count for all environments
all_gateway_services=[]
total_workspaces=0

klcr_json=$(printf '{"klcr_version":"%s", "kong_environments": %d, "kong": [' $KLCR_VERSION $ENV_COUNT)

for ((i=0; $i<$ENV_COUNT; i++)); do
    # A little clunky but this works
    env=$(jq -r '.environments.['$i'].environment' $INPUT_FILE)
    host=$(jq -r '.environments.['$i'].admin_host' $INPUT_FILE)
    token=$(jq -r '.environments.['$i'].admin_token' $INPUT_FILE)

    status=$(fetch_gateway_status "$host" "$token")

    if [[ "$NO_PRETTY_PRINT" -ne 1 ]]; then
      printf " KONG ENVIRONMENT: $env\n";
      printf " ADMIN API       : $host\n";
      printf " STATUS          : $status\n";
    fi

    # Count the unique services
    total_services_output=""
    summary_output=""

    # Track all services separately so we can do one final check for discrete across all workspaces
    cp_services=[]

    # Fetch list of workspaces
    workspaces=$(fetch_workspaces "$host" "$token")
    klcr_json+=$(printf '{ "environment": "%s", "status": "%s", "host": "%s", "workspaces": [' "$env" "$status" "$host")

    if [ -n "$workspaces" ]; then
      # Iterate over each workspace and add services to the array
      total_services_output+=$(printf 'Workspace\tGateway Services\tDiscrete Services\n';)
      for workspace in $workspaces; do
        total_workspaces=$(($total_workspaces + 1))
        workspace_svc_list=$(fetch_workspace_services "$host" "$token" "$workspace" "$MASTER" "$MINIONS")
        cp_services=$(echo "$cp_services $workspace_svc_list" | jq -s 'add')
        all_gateway_services=$(echo "$all_gateway_services $workspace_svc_list" | jq -s 'add')

        services_count=$(echo "$workspace_svc_list" | jq 'length')
        discrete_count=$(echo "$workspace_svc_list" | jq 'unique | length')

        total_services_output+=$(printf '\n%s\t%d\t%d\n' "$workspace" "$services_count" "$discrete_count")

        klcr_json+=$(printf '{"workspace": "%s", "gateway_services": %d, "discrete_services": %d},' "$workspace" $services_count $discrete_count)
      done

      # remove the trailing comma (,) from the json constructed above
      klcr_json=$(echo $klcr_json | sed 's/.$//')
    else
      echo "No workspaces to process."
    fi

    # close the json array
    klcr_json+="], "
    total_services_count=$(echo "$cp_services" | jq 'length')
    total_discrete_cross_workspace_count=$(echo "$cp_services" | jq 'unique | length')

    # let's add totals per workspace
    klcr_json+=$(printf '"workspaces_services": %d, "workspaces_discrete": %d},' $total_services_count $total_discrete_cross_workspace_count)

    if [ -n "$total_services_output" ]; then
      total_services_output+=$(printf '\n%s\t%s\t%s\n'  "" "" "";)
      total_services_output+=$(printf '\n%s\t%d\t%s\n'  "Total" $total_services_count "$total_discrete_cross_workspace_count (x-workspace)";)

      if [[ "$NO_PRETTY_PRINT" -ne 1 ]]; then
        echo "$total_services_output" | prettytable 3
      fi
    fi

    all_gateway_services_count=$(echo "$all_gateway_services" | jq 'length')
    all_discrete_services_count=$(echo "$all_gateway_services" | jq 'unique | length')

    summary_output+=$(printf '%s\t%s\t%s\t%s\n'  "Kong Environments" "Total Workspaces" "Gateway Services" "Discrete Services")
    summary_output+=$(printf '\n%d\t%d\t%d\t%d (x-environment)\n'  $ENV_COUNT $total_workspaces "$all_gateway_services_count" "$all_discrete_services_count")

    # Write license output to file, including discrete services information
    license=$(fetch_license_report $env $host $token)
    echo $license > "$OUTPUT_DIR/$env.json"

    if [[ "$NO_PRETTY_PRINT" -ne 1 ]]; then
      printf "\n"
    fi
done

klcr_json=$(echo $klcr_json | sed 's/.$//')

if [[ "$NO_PRETTY_PRINT" -ne 1 ]]; then
  printf " SUMMARY\n"
  echo "$summary_output" | prettytable 4
  printf "\n"
fi

klcr_json+=$(printf '], "total_workspaces": %d, "total_gateway_services": %d, "total_discrete_services": %d }' $total_workspaces $all_gateway_services_count $all_discrete_services_count)

# store klcr information in its own JSON file
echo $klcr_json > "$OUTPUT_DIR/klcr.json"
