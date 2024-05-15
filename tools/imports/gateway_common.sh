#!/usr/bin/env bash

####
# Copyright (c) 2024 Kong, Inc.
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

# KONG GATEWAY *****************************************************************************************************************************************

# Generic method for hitting endpoints on the Admin API
function kong_gateway_fetch_from_admin_api() {
  local api="$1"
  local token="$2"
  local path="$3"
  local flag=""

  flag=${4:-"-s"}

  if output=$(curl "${SKIP_VERIFICATION:-'-k'}" "$flag" -X GET "${api}${path}" -H "Kong-Admin-Token: ${token}" -H "Content-Type: application/json"); then
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
  local workspaces=$(echo "${raw}" | jq -r '.data[].name')

  # we need to make sure we check all the "pages" in case there are more than 1000 workspaces,
  local offset=$(echo $raw | jq -r '.next // empty')

  # let's grab $size workspaces at a time until we run out
  while [[ -n "${offset}" ]]; do
    raw=$(kong_gateway_fetch_from_admin_api $api $token $offset | jq)
    workspaces="$workspaces $(echo $raw | jq -r '.data[].name')"
    offset=$(echo "${raw}" | jq -r '.next // empty')
  done

  echo "${workspaces}" | xargs -n1 | sort | xargs
}

# Get a formatted list of services in the workspace
function kong_gateway_fetch_workspace_services() {
  local size=1000
  local api="$1"
  local token="$2"
  local path="/$3/services?size=$size"

  # get the first batch of $size workspaces
  local raw=$(kong_gateway_fetch_from_admin_api $api $token $path | jq)
  local services=$(echo "${raw}" | jq -r '[.data[] | {service: "\(.protocol)://\(.host):\(.port)\(.path)"}]')

  # we need to make sure we check all the "pages" in case there are more than 1000 workspaces,
  local offset=$(echo $raw | jq -r '.next // empty')

  # let's grab $size workspaces at a time until we run out
  while [[ -n "${offset}" ]]; do
    raw=$(kong_gateway_fetch_from_admin_api $api $token $offset | jq)
    nextBatch=$(echo "${raw}" | jq -r '[.data[] | {service: "\(.protocol)://\(.host):\(.port)\(.path)"}]')
    services=$(jq --argjson arr1 "$services" --argjson arr2 "$nextBatch" -n '$arr1 + $arr2')
    offset=$(echo "${raw}" | jq -r '.next // empty')
  done

  if [[ ! -z "$DISCRETE" ]]; then
    finds=$(echo "${DISCRETE}" | jq -r '.[].find')
    local i=0

    for f in $finds; do
      fnd=$(echo "${DISCRETE}" | jq -r --argjson x $i '.[$x].find')
      rep=$(echo "${DISCRETE}" | jq -r --argjson x $i '.[$x].replace_with')
      services=$(echo "${services}" | jq -r -s --arg find $fnd --arg replace_with $rep 'add | .[].service |= gsub($find;$replace_with)')
      i=$((i+1))
    done
  fi

  echo "${services}"
}

# Get a raw list of services per workspace
function kong_gateway_fetch_workspace_services_raw() {
  local size=1000
  local api="$1"
  local token="$2"
  local path="/$3/services?size=$size"

  # get the first batch of $size services
  local raw=$(kong_gateway_fetch_from_admin_api $api $token $path | jq)
  local services="${raw}"

  # we need to make sure we check all the "pages" in case there are more than 1000 services,
  local offset=$(echo "${raw}" | jq -r '.next // empty')

  # let's grab $size workspaces at a time until we run out
  while [[ -n "${offset}" ]]; do
    raw=$(kong_gateway_fetch_from_admin_api $api $token $offset | jq)
    services=$(
      jq -s '[.[0].data[], .[1].data[]]' <(echo "${services}") <(echo "${raw}"))
    offset=$(echo "${raw}" | jq -r '.next // empty')
  done

  echo "${services}"
}

# Get a singular service
function kong_gateway_fetch_workspace_service_raw() {
  local size=1000
  local api="$1"
  local token="$2"
  local workspace="$3"
  local service_id="$4"
  local path="/$workspace/services/$service_id"

  # get the first batch of $size services
  local raw=$(kong_gateway_fetch_from_admin_api $api $token $path | jq)
  local service="${raw}"

  echo "${service}"
}

# Get a raw list of routes per service
function kong_gateway_fetch_routes_raw() {
  local size=1000
  local api="$1"
  local token="$2"
  local workspace="$3"
  local path="/$workspace/routes?size=$size"

  # get the first batch of $size rotues
  local raw=$(kong_gateway_fetch_from_admin_api $api $token $path | jq)
  local routes="${raw}"

  # We need to make sure we check all the "pages" in case there are more than 1000 routes
  local offset=$(echo "${raw}" | jq -r '.next // empty')

  # let's grab $size workspaces at a time until we run out
  while [[ -n "${offset}" ]]; do
    raw=$(kong_gateway_fetch_from_admin_api $api $token $offset | jq)
    routes=$(
      jq -s '[.[0].data[], .[1].data[]]' <(echo "${routes}") <(echo "${raw}"))
    offset=$(echo "${raw}" | jq -r '.next // empty')
  done

  echo "${routes}"
}
