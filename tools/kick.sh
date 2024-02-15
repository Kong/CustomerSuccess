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
  printf "Help is on the way!\n"
}

# check if jq is installed
if ! command -v jq &> /dev/null
then
    echo "jq could not be found. Please install it by following instructions at https://jqlang.github.io/jq/"
    exit 1
fi

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
          OUTPUT_FILE=$2
          shift 2
        else
          echo "Error: Output file is missing" >&2
          exit 1
        fi
        ;;
      -p|--pretty-print)
        PRETTY_PRINT=1
        shift
        ;;
      -h|--help)
        print_help
        exit 1
        ;;
      -*|--*=)   # unsupported flags
        echo "Error: Unsupported flag $1" >&2
        exit 1
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
fi

if [[ -z "$OUTPUT_FILE" ]]; then
    OUTPUT_FILE="kong.json"
fi

printf "\n";

ENV_COUNT=$(jq '. | length' $INPUT_FILE)

for ((i=0; $i<$ENV_COUNT; i++)); do
  # A little clunky but this works
    env=$(jq -r '.['$i'].environment' $INPUT_FILE)
    host=$(jq -r '.['$i'].admin_host' $INPUT_FILE)
    token=$(jq -r '.['$i'].admin_token' $INPUT_FILE)
    license=$(jq -r '.['$i'].license_report' $INPUT_FILE)

    printf " KONG CLUSTER: $env\n";
    printf " ADMIN HOST  : $host\n";
    {
        # Fetch list of workspaces
        workspaces=$(curl -s -X GET ${host}/workspaces -H "Kong-Admin-Token: ${token}" | jq -r '.data[].name' | sort)

        # Count the unique services
        total_discrete_count=0
        total_services_count=0

        # Track all services separately so we can do one final check for discrete across all workspaces
        cp_services=[]

        # Iterate over each workspace and add services to the array
        printf 'Workspace\tGateway Svcs\tDiscrete Svcs\n';
        for workspace in $workspaces; do
            workspace_services=$(curl -s -X GET ${host}/${workspace}/services -H "Kong-Admin-Token: ${token}" | jq -r '[.data[] | {service: "\(.protocol)://\(.host):\(.port)\(.path)"}]')
            cp_services=$(echo $cp_services $workspace_services | jq -s 'add')

            services_count=$(echo $workspace_services | jq 'length')
            discrete_count=$(echo $workspace_services | jq 'unique | length')

            printf '%s\t%d\t%d\n' $workspace $services_count $discrete_count;

            total_services_count=$(($total_services_count + $services_count))
            total_discrete_count=$(($total_discrete_count + $discrete_count))
        done


        total_discrete_cross_workspace_count=$(echo $cp_services | jq 'unique | length')

        printf '%s\t%s\t%s\n'  "" "" "";
        printf '%s\t%d\t%s\n'  "Total" $total_services_count "$total_discrete_cross_workspace_count (x-workspace)";

    } | prettytable 3

    printf "\n"
done

{
    # Count the unique services
    all_gateway_services=[]
    total_workspaces=0
    total_kong_environments=0

    # not thrilled to repeat the loop here as a whole
    for ((i=0; $i<$ENV_COUNT; i++)); do
      # A little clunky but this works
        host=$(jq -r '.['$i'].admin_host' $INPUT_FILE)
        token=$(jq -r '.['$i'].admin_token' $INPUT_FILE)
        license=$(jq -r '.['$i'].license_report' $INPUT_FILE)

        total_kong_environments=$(($total_kong_environments + 1))
        # Fetch list of workspaces
        workspaces=$(curl -s -X GET ${host}/workspaces -H "Kong-Admin-Token: ${token}" | jq -r '.data[].name' | sort)

        # Track all services separately so we can do one final check for discrete across all workspaces
        cp_services=[]

        # Iterate over each workspace and add services to the array
        for workspace in $workspaces; do
            total_workspaces=$(($total_workspaces + 1))
            workspace_services=$(curl -s -X GET ${host}/${workspace}/services -H "Kong-Admin-Token: ${token}" | jq -r '[.data[] | {service: "\(.protocol)://\(.host):\(.port)\(.path)"}]')
            all_gateway_services=$(echo $all_gateway_services $workspace_services | jq -s 'add')
        done
    done

    all_gateway_services_count=$(echo $all_gateway_services | jq 'length')
    all_discrete_services_count=$(echo $all_gateway_services | jq 'unique | length')

    printf '%s\t%s\t%s\t%s\n'  "Kong Clusters" "Total Workspaces" "Gateway Svcs" "Discrete Svsc"
    printf '%d\t%d\t%d\t%d\n'  $total_kong_environments $total_workspaces $all_gateway_services_count $all_discrete_services_count

} | prettytable 4

printf "\n"
