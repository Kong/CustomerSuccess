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

KLCR_VERSION="2.3.1"

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
  -i, --input-file FILE         Details of every Kong environment.
  -l, --list-discrete-services  Lists discrete services in the generated klcr.json file.
  -o, --output-dir DIR          Name of the directory where all license reports will be saved.
  -s, --suppress                Suppress printing to standard output.
  -v, --version                 Shows the version of KLCR.
  -k, --insecure                Makes curl skip the verification step and proceed without checking.
  -h, --help                    Display this help message.

Example:
  $(basename "$0") -i input.json -o output_dir -l

Description:
  This script analyzes Kong environments and provides a summary of gateway services, and
  discrete services. In addition, it collects the output of the license report for every 
  Kong Enterprise enviroment specified.
  
  KLCR requires 'jq' to be installed. You can download it from
  https://jqlang.github.io/jq/

  See https://github.com/Kong/CustomerSuccess for more information.

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

# KONG GATEWAY *****************************************************************************************************************************************

# Generic method for hitting endpoints on the Admin API
function kong_gateway_fetch_from_admin_api() {
  local api="$1"
  local token="$2"
  local path="$3"
  local flag=""

  if [[ -n "$4" ]]; then
    flag="$4"
  fi

  if output=$(curl $SKIP_VERIFICATION -s $flag -X GET "${api}${path}" -H "Kong-Admin-Token: ${token}" -H "Content-Type: application/json"); then
    response="$output"
  else
    echo "Error: Failed to fetch ${path} from ${api}" >&2
    return 1
  fi

  echo "$response"
}

# Gets the license report 
function kong_gateway_fetch_license_report() {
  local name="$1"
  local api="$2"
  local token="$3"
  local path="/license/report"

  echo $(kong_gateway_fetch_from_admin_api $api $token $path) | jq -s 'add'
}

function kong_gateway_fetch_gateway_status() {
  local api="$1"
  local token="$2"
  local path="/status"
  local flag="-I"

  status=$(kong_gateway_fetch_from_admin_api $api $token $path $flag | head -n 1)

  if [[ -n $(echo $status | grep 200) ]]; then
    status="Healthy"
  fi

  # remove the trailing newline first, and then the white space
  echo "${status//[$'\t\r\n']}"
}

function kong_gateway_fetch_gateway_version() {
  local api="$1"
  local token="$2"
  local path="/default/kong"

  version=$(kong_gateway_fetch_from_admin_api $api $token $path | jq -r '.version')

  echo $version
}

function kong_gateway_fetch_workspaces() {
  local size=1000
  local api="$1"
  local token="$2"
  local path="/workspaces?size=$size"

  # get the first batch of $size workspaces
  local raw=$(kong_gateway_fetch_from_admin_api $api $token $path | jq)
  local workspaces=$(echo $raw | jq -r '.data[].name')

  # we need to make sure we check all the "pages" in case there are more than 1000 workspaces,
  local offset=$(echo $raw | jq -r '.next // empty')

  # let's grab $size workspaces at a time until we run out
  while [[ -n "${offset}" ]]; do
    raw=$(kong_gateway_fetch_from_admin_api $api $token $offset | jq)
    workspaces="$workspaces $(echo $raw | jq -r '.data[].name')"
    offset=$(echo $raw | jq -r '.next // empty')
  done  

  echo $workspaces | xargs -n1 | sort | xargs
}

# Get a list of services in the workspace
function kong_gateway_fetch_workspace_services() {
  local size=1000
  local api="$1"
  local token="$2"
  local path="/$3/services?size=$size"

  # get the first batch of $size workspaces
  local raw=$(kong_gateway_fetch_from_admin_api $api $token $path | jq)
  local services=$(echo $raw | jq -r '[.data[] | {service: "\(.protocol)://\(.host):\(.port)\(.path)"}]')

  # we need to make sure we check all the "pages" in case there are more than 1000 workspaces,
  local offset=$(echo $raw | jq -r '.next // empty')

  # let's grab $size workspaces at a time until we run out
  while [[ -n "${offset}" ]]; do
    raw=$(kong_gateway_fetch_from_admin_api $api $token $offset | jq)
    nextBatch=$(echo $raw | jq -r '[.data[] | {service: "\(.protocol)://\(.host):\(.port)\(.path)"}]')
    services=$(jq --argjson arr1 "$services" --argjson arr2 "$nextBatch" -n '$arr1 + $arr2')
    offset=$(echo $raw | jq -r '.next // empty')
  done

  if [[ ! -z "$DISCRETE" ]]; then  
    finds=$(echo $DISCRETE | jq -r '.[].find')
    local i=0
    
    for f in $finds; do
      fnd=$(echo $DISCRETE | jq -r --argjson x $i '.[$x].find')
      rep=$(echo $DISCRETE | jq -r --argjson x $i '.[$x].replace_with')
      services=$(echo $services | jq -r -s --arg find $fnd --arg replace_with $rep 'add | .[].service |= gsub($find;$replace_with)')      
      i=$((i+1))
    done
  fi

  echo $services
}

# Dev portal status in a workspace
function kong_gateway_fetch_workspace_dev_portal_status() {
  local api="$1"
  local token="$2"
  local path="/$3/default/kong"

  local portal=$(kong_gateway_fetch_from_admin_api $api $token $path | jq '.configuration.portal')

  if [[ "true" == "${portal}" ]]; then
    portal="Enabled"
  else
    portal="Disabled"
  fi

  echo $portal
}

function handle_kong_enterprise() {
  local env="$1"
  local api="$2"
  local token="$3"

  local status=$(kong_gateway_fetch_gateway_status "$api" "$token")
  local version=$(kong_gateway_fetch_gateway_version "$api" "$token")
  local dev_portal=$(kong_gateway_fetch_workspace_dev_portal_status "$api" "$token")  

  if [[ "$NO_PRETTY_PRINT" -ne 1 ]]; then
    printf " Environment   : ${env}\n";
    printf " Deployment    : Enterprise ($version)\n";
    printf " Admin API     : $api\n";
    printf " Gateway Status: $status\n";
    printf " Dev Portal    : $dev_portal\n";
  fi

  # Fetch list of workspaces  
  workspaces=$(kong_gateway_fetch_workspaces "$api" "$token")  
  klcr_json+=$(printf '{ "environment": "%s", "deployment": "enterprise", "version": "%s", "admin_api": "%s", "status": "%s", "dev_portal": "%s", "workspaces": [' "${env}" "${version}" "$api" "$status" "$dev_portal" )

  enterprise_services_output=""
  cp_services=[]

  if [ -n "$workspaces" ]; then
    # Iterate over each workspace and add services to the array
    enterprise_services_output+=$(printf 'Workspace\tGateway Services\tDiscrete Services\n';)
    dev_portal_count=0

    for workspace in $workspaces; do
      total_workspaces=$(($total_workspaces + 1))
      workspace_svc_list=$(kong_gateway_fetch_workspace_services "$api" "$token" "$workspace")
      cp_services=$(echo "$cp_services $workspace_svc_list" | jq -s 'add')
      all_gateway_services=$(echo "$all_gateway_services $workspace_svc_list" | jq -s 'add')

      services_count=$(echo "$workspace_svc_list" | jq 'length')
      discrete_count=$(echo "$workspace_svc_list" | jq 'unique | length')
      enterprise_services_output+=$(printf '\n%s\t%d\t%d\n' "$workspace" "$services_count" "$discrete_count")

      if [ $LIST_DISCRETE_SERVICES ]; then
        klcr_json+=$(printf '{"workspace": "%s", "gateway_services": %d, "discrete_services": %d, "discrete_services_list": %s},' "$workspace" $services_count $discrete_count $(echo $workspace_svc_list | jq -c 'unique|sort'))
      else
        klcr_json+=$(printf '{"workspace": "%s", "gateway_services": %d, "discrete_services": %d},' "$workspace" $services_count $discrete_count)
      fi
    done

    # remove the trailing comma (,) from the json constructed above
    klcr_json=$(echo $klcr_json | sed 's/.$//')
  else
    echo "No workspaces to process."
  fi

  # let's add totals per workspace
  enterprise_services_count=$(echo "$cp_services" | jq 'length')
  enterprise_discrete_cross_workspace_count=$(echo "$cp_services" | jq 'unique | length')

  klcr_json+=$(printf '], "gateway_services": %d, "discrete_services": %d },' $enterprise_services_count $enterprise_discrete_cross_workspace_count )  

  if [ -n "$enterprise_services_output" ]; then
    enterprise_services_output+=$(printf '\n%s\t%s\t%s\n'  "" "" "";)
    enterprise_services_output+=$(printf '\n%s\t%d\t%s\n'  "Total" $enterprise_services_count "$enterprise_discrete_cross_workspace_count (x-workspace)";)

    if [[ "$NO_PRETTY_PRINT" -ne 1 ]]; then
      echo "$enterprise_services_output" | prettytable 3
    fi
  fi

  # Write license output to file, including discrete services information
  license=$(kong_gateway_fetch_license_report "${env}" $api $token)
  echo $license > "$OUTPUT_DIR/$env.json"  
}



# KONG KONNECT *****************************************************************************************************************************************

# Generic method for hitting endpoints on the Konnect API
function kong_konnect_fetch_from_api() {
  local api="$1"
  local token="$2"

  if [ -n "$3" ]; then
    local path="$3"
  else
    local path=""
  fi

  if output=$(curl $SKIP_VERIFICATION -s -X GET "${api}${path}" -H "Authorization: Bearer ${token}" -H "Content-Type: application/json"); then
    response="$output"
  else
    echo "Error: Failed to fetch ${path} from ${api}" >&2
    exit 1
  fi

  local response_code=$(echo $response | jq -r '.status // empty')

  # there won't be an error code returned if the call is successful
  if [ -z "$response_code" ]; then
    echo "$response"
  else
    echo ""
  fi
}

# Get a list of all control planes, but only if a control plane ID wasn't provided
function kong_konnect_fetch_control_planes() {
  # page size must be 100 or less
  local size=100
  local api="$1"
  local token="$2"
  local cp="$3"

  if [ "$cp" == "null" ]; then
    local path="/control-planes?page%5Bsize%5D=$size&page%5Bnumber%5D="
    local raw=$(kong_konnect_fetch_from_api $api $token "${path}1" | jq)

    # no need to keep on going if we got nothing back 
    if [ -z "$raw" ]; then
      return
    fi

    local control_planes=$(echo $raw | jq -r '[.data[] | {id: "\(.id)", name: "\(.name)"}]')
    local total_cps=$(echo $raw | jq -r '.meta.page.total')
    
    # if we have more control planes than our page size, it's time to loop some
    if [[ $total_cps -gt $size ]]; then 
      # first things first, let's see how many iterations we have to go through
      local pages=$(( ($total_cps + $size - 1)/$size ))

      # start at page 2, since we already got the first page above
      for (( page=2; page<=$pages; page++ )); do        
        raw=$(kong_konnect_fetch_from_api $api $token "${path}${page}" | jq)
        nextBatch=$(echo $raw | jq -r '[.data[] | {id: "\(.id)", name: "\(.name)"}]')
        control_planes=$(jq  --argjson arr1 "$control_planes" --argjson arr2 "$nextBatch" -n '$arr1 + $arr2')
      done
    fi
  else
    local path="/control-planes/$cp"
    local control_planes=$(kong_konnect_fetch_from_api $api $token $path | jq -r '[{id: "\(.id)", name: "\(.name)"}]')
  fi

  echo $control_planes | jq -r 'sort_by(.name) | .[].id'
}

# Get a list of services in the control plane
function kong_konnect_fetch_control_plane_services() {
  local size=1000
  local api="$1"
  local token="$2"
  local path="/control-planes/$3/core-entities/services?size=$size"

  local raw=$(kong_konnect_fetch_from_api $api $token $path | jq)
  local services=$(echo $raw | jq -r '[.data[] | {service: "\(.protocol)://\(.host):\(.port)\(.path)"}]')

  # we need to make sure we check all the "pages" in case there are more than 1000 workspaces,
  local offset=$(echo $raw | jq -r '.next // empty')

  # let's grab $size workspaces at a time until we run out
  while [[ -n "${offset}" ]]; do
    raw=$(kong_konnect_fetch_from_api $api $token $offset | jq)
    nextBatch=$(echo $raw | jq -r '[.data[] | {service: "\(.protocol)://\(.host):\(.port)\(.path)"}]')
    services=$(jq --argjson arr1 "$services" --argjson arr2 "$nextBatch" -n '$arr1 + $arr2')
    offset=$(echo $raw | jq -r '.next // empty')
  done  

  if [[ ! -z "$DISCRETE" ]]; then  
    finds=$(echo $DISCRETE | jq -r '.[].find')
    local i=0
    
    for f in $finds; do
      fnd=$(echo $DISCRETE | jq -r --argjson x $i '.[$x].find')
      rep=$(echo $DISCRETE | jq -r --argjson x $i '.[$x].replace_with')
      services=$(echo $services | jq -r -s --arg find $fnd --arg replace_with $rep 'add | .[].service |= gsub($find;$replace_with)')      
      i=$((i+1))
    done
  fi

  echo $services
}

# Gets a control plane name
function kong_konnect_fetch_control_plane_info() {
  local api="$1"
  local token="$2"
  local path="/control-planes/$3"

  local info=$(kong_konnect_fetch_from_api $api $token $path | jq)

  echo $info
}

# Kong Konnect-specific motions
function handle_kong_konnect() {
  local env="$1"
  local api="$2"
  local token="$3"
  local control_plane_id="$4"
  local control_plane_type_filter="$5"
  local name=""

  if [[ "$NO_PRETTY_PRINT" -ne 1 ]]; then
    printf " Environment   : $env\n";
    printf " Deployment    : Konnect\n";
    printf " Admin API     : $api\n";
  fi

  klcr_json+=$(printf '{ "environment": "%s", "deployment": "konnect", "admin_api": "%s", "control_planes": [' "$env" "$api")
  control_planes=$(kong_konnect_fetch_control_planes $api $token $control_plane_id)

  konnect_services=[]
  konnect_services_output=""

  if [ -n "$control_planes" ]; then
    # Iterate over each control plane and add services to the array
    konnect_services_output+=$(printf 'Control Planes\tGateway Services\tDiscrete Services\tControl Plane Type\n';)

    for cp in $control_planes; do
      cp_info=$(kong_konnect_fetch_control_plane_info $api $token $cp)
      cp_type=$(echo $cp_info | jq -r '.config.cluster_type')

      # if a filter was passed in, we'll honor it
      if [ "$control_plane_type_filter" != "null" ]; then
        match_found=$(echo $cp_type | grep -E "($control_plane_type_filter)")
        
        if [ -z "$match_found" ]; then
          continue
        fi
      fi

      cp_name=$(echo $cp_info | jq -r '.name')      
      cp_services=$(kong_konnect_fetch_control_plane_services "$api" "$token" $cp)

      if [ -z "$cp_services" ]; then
        cp_services=()
      fi

      total_control_planes=$(($total_control_planes + 1))
      konnect_services=$(echo "$konnect_services $cp_services" | jq -s 'add')
      all_gateway_services=$(echo "$all_gateway_services $cp_services" | jq -s 'add')

      services_count=$(echo "$cp_services" | jq 'length')
      discrete_count=$(echo "$cp_services" | jq 'unique | length')

      konnect_services_output+=$(printf '\n%s\t%d\t%d\t%s\n' "$cp_name" "$services_count" "$discrete_count" "$cp_type")

      klcr_json+=$(printf '{"control_plane": "%s"' "$cp_name")
      klcr_json+=$(printf ',"control_plane_id": "%s"' $cp)
      klcr_json+=$(printf ',"control_plane_type": "%s"' "$cp_type")
      klcr_json+=$(printf ',"gateway_services": %d' $services_count)
      klcr_json+=$(printf ',"discrete_services": %d' $discrete_count)

      if [ $LIST_DISCRETE_SERVICES ]; then
        klcr_json+=$(printf ',"discrete_services_list": %s' $(echo $cp_services | jq -c 'unique|sort'))  
      fi

      klcr_json+="},"
    done

    # remove the trailing comma (,) from the json constructed above
    klcr_json=$(echo $klcr_json | sed 's/.$//')

  else
    printf ' --\n ERROR: No control planes to process. Please check permissions for the access token provided.\n'
  fi

  # let's add totals per control plane
  konnect_services_count=$(echo "$konnect_services" | jq 'length')
  konnect_discrete_cross_control_plane_count=$(echo "$konnect_services" | jq 'unique | length')
  klcr_json+=$(printf '], "gateway_services": %d, "discrete_services": %d },' $konnect_services_count $konnect_discrete_cross_control_plane_count)

  if [ -n "$konnect_services_output" ]; then
    konnect_services_output+=$(printf '\n%s\t%s\t%s\t%s\n'  "" "" "" "";)
    konnect_services_output+=$(printf '\n%s\t%d\t%s\t%s\n'  "Total" $konnect_services_count "$konnect_discrete_cross_control_plane_count (x-control-plane)" "";)

    if [[ "$NO_PRETTY_PRINT" -ne 1 ]]; then
      echo "$konnect_services_output" | prettytable 4
    fi
  fi
  
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
      -l|--list-discrete-services)
        LIST_DISCRETE_SERVICES=1
        shift
        ;;        
      -k|--insecure)
        SKIP_VERIFICATION=$1
        shift
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

# Check that jq is at version 1.7.0 or above
jq_ver_major=`jq -V | cut -f2 -d- | cut -d. -f1`
jq_ver_minor=`jq -V | cut -f2 -d- | cut -d. -f2`

if [[ "$jq_ver_major" -lt 1 ]] || { [[ "$jq_ver_major" -eq 1 ]] && [[ "$jq_ver_minor" -lt 7 ]]; }; then
    echo "jq version is below version 1.7, please upgrade to version 1.7 before continuing"
    exit 1
fi

if [[ -z "$INPUT_FILE" ]]; then
    echo "Input file is missing. Please specify one with the --input-file (-i) option."
    exit 1
fi

if [[ -z "$OUTPUT_DIR" ]]; then
    echo "Output directory is missing. Please specify one with the --output-dir (-o) option."
    exit 1
fi

# Create the OUTPUT_DIR if it doesn't exist
if [ ! -d "$OUTPUT_DIR" ]; then
  mkdir "$OUTPUT_DIR"
fi 

printf "\n";

ENV_COUNT=$(jq -r '[.environments[]] | length' $INPUT_FILE)
ENVS=$(jq -r '.environments[].deployment' $INPUT_FILE)
DISCRETE=$(jq -r -c '.discrete' $INPUT_FILE)

# Count for all environments
all_gateway_services=[]
summary_output=""
klcr_json=$(printf '{"klcr_version":"%s", "discrete": %s, "kong_environments": %d, "kong": [' $KLCR_VERSION "$DISCRETE" $ENV_COUNT)
i=0

for v in $ENVS; do
    # A little clunky but this works
    env=$(jq -r --argjson e $i '.environments.[$e].environment' $INPUT_FILE)
    api=$(jq -r --argjson e $i '.environments.[$e].admin_api' $INPUT_FILE)
    token=$(jq -r --argjson e $i '.environments.[$e].admin_token' $INPUT_FILE)
    deployment=$(jq -r --argjson e $i '.environments.[$e].deployment' $INPUT_FILE)
    # the cp id is an optional parameter
    control_plane_id=$(jq -r --argjson e $i '.environments.[$e].control_plane_id' $INPUT_FILE)
    # as is the filter
    control_plane_type_filter=$(jq -r --argjson e $i '.environments.[$e].control_plane_type_filter' $INPUT_FILE)

    # Track all services separately so we can do one final check for discrete across all workspaces
    cp_services=[]

    if [[ $deployment == "enterprise" ]]; then
      handle_kong_enterprise "${env}" $api $token
    elif [[ $deployment == "konnect" ]]; then
      handle_kong_konnect "${env}" $api $token $control_plane_id $control_plane_type_filter
    else
      echo "Unsupported deployment: $deployment"
    fi

    all_gateway_services_count=$(echo "$all_gateway_services" | jq 'length')
    all_discrete_services_count=$(echo "$all_gateway_services" | jq 'unique | length')

    if [[ "$NO_PRETTY_PRINT" -ne 1 ]]; then
      printf "\n"
    fi

    i=$((i+1))
done

klcr_json=$(echo $klcr_json | sed 's/.$//')

if [[ "$NO_PRETTY_PRINT" -ne 1 ]]; then
  summary_output+=$(printf '%s\t%s\t%s\n'  "Kong Environments" "Gateway Services" "Discrete Services")
  summary_output+=$(printf '\n%d\t%d\t%d (x-environment)\n'  $i "$all_gateway_services_count" "$all_discrete_services_count")

  printf " SUMMARY\n"
  echo "$summary_output" | prettytable 3
  printf "\n"
fi

klcr_json+=$(printf '], "total_gateway_services": %d, "total_discrete_services": %d }' $all_gateway_services_count $all_discrete_services_count)

# store klcr information in its own JSON file
echo $klcr_json > "$OUTPUT_DIR/klcr.json"
