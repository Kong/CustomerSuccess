#!/usr/bin/env bash

####
# Copyright (c) 2024, Kong Inc.
# Copyright (c) 2016-2021 Jakob Westhoff <jakob@westhoffswelt.de>
# All rights reserved.
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

# Variables for the overall totals
all_gateway_services=[]
all_gateway_services_count=0
all_discrete_services_count=0
environments_count=0
workspaces_count=0

for cp in "$@"; do
    printf "\n KONG ADMIN HOST : $cp\n";
    {
        # Fetch list of workspaces
        workspaces=$(curl -s -X GET ${cp}/workspaces -H "Kong-Admin-Token: ${KONG_ADMIN_TOKEN}" | jq -r '.data[].name' | sort)

        # increment total counts (currently not working)
        workspaces_count=$(($workspaces_count + ${#workspaces[@]}))
        environments_count=$(($environments_count + 1))

        # Count the unique services
        total_discrete_count=0
        total_services_count=0

        # Track all services separately so we can do one final check for discrete across all workspaces
        cp_services=[]

        # Iterate over each workspace and add services to the array
        printf 'Workspace\tGateway Svcs\tDiscrete Svcs\n';
        for workspace in $workspaces; do    
            workspace_services=$(curl -s -X GET ${cp}/${workspace}/services -H "Kong-Admin-Token: ${KONG_ADMIN_TOKEN}" | jq -r '[.data[] | {service: "\(.protocol)://\(.host):\(.port)\(.path)"}]')
            cp_services=$(echo $cp_services $workspace_services | jq -s 'add')
        
            services_count=$(echo $workspace_services | jq 'length')
            discrete_count=$(echo $workspace_services | jq 'unique | length')
            
            printf '%s\t%d\t%d\n' $workspace $services_count $discrete_count;

            total_services_count=$(($total_services_count + $services_count))
            total_discrete_count=$(($total_discrete_count + $discrete_count))
        done

        all_gateway_services=$(echo $all_gateway_services $cp_services | jq -s 'add')
        total_discrete_cross_workspace_count=$(echo $cp_services | jq 'unique | length')

        printf '%s\t%s\t%s\n'  "" "" "";
        printf '%s\t%d\t%s\n'  "Total" $total_services_count "$total_discrete_cross_workspace_count (x-workspace)";

    } | prettytable 3

    printf "\n" 
done

{
    all_gateway_services_count=$(echo $all_gateway_services | jq 'length')
    all_discrete_services_count=$(echo $all_gateway_services | jq 'unique | length')

    printf '%s\t%s\t%s\t%s\n' "Kong Clusters" "Workspaces" "Gateway Svcs" "Discrete Svcs";
    printf '%d\t%d\t%d\t%d\n' $environments_count $workspaces_count $all_gateway_services_count $all_discrete_services_count;

} | prettytable 4

    printf "\n" 
