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

# shellcheck source=/dev/null
source imports/prettytable.sh
# shellcheck source=/dev/null
source imports/gateway_common.sh
# shellcheck source=/dev/null
source imports/params.sh

NO_PRETTY_PRINT=0
ENV_COUNT=$(jq -r '[.environments[]] | length' $INPUT_FILE)
ENVS=$(jq -r '.environments[].deployment' $INPUT_FILE)
DISCRETE=$(jq -r -c '.discrete' $INPUT_FILE)

# Count for all environments
summary_output=""
klcr_json=$(printf '{"klcr_version":"%s", "discrete": %s, "kong_environments": %d, "kong": [' "$KLCR_VERSION" "$DISCRETE" "$ENV_COUNT")
i=0

# For each environment in the input file, grab a list of workspaces, servies, and routes
for v in $ENVS; do
  env=$(jq -r --argjson e $i '.environments.[$e].environment' $INPUT_FILE)
  api=$(jq -r --argjson e $i '.environments.[$e].admin_api' $INPUT_FILE)
  token=$(jq -r --argjson e $i '.environments.[$e].admin_token' $INPUT_FILE)
  deployment=$(
    jq -r --argjson e $i '.environments.[$e].deployment' "$INPUT_FILE")
  version=$(kong_gateway_fetch_gateway_version "$api" "$token")

  # Get a list of workspaces
  workspaces=$(kong_gateway_fetch_workspaces "$api" "$token")

  if [[ "$NO_PRETTY_PRINT" -ne 1 ]]; then
    printf " Environment   : %s\n" "${env}";
    printf " Deployment    : Enterprise (%s)\n" "$version";
    printf " Admin API     : %s" "${api}\n";
    printf " Workspaces    : %s" "${workspaces}\n";
    summary_output+=$(
     printf '%s\t%s\t%s\t%s\t%s\t%s\n' "Workspace" "Kong Route Name" "Kong Route Path" "Service Name" "Service Host" "Service Path"
    )
  fi

  # For each workspace, get a list of services
  for workspace in $workspaces; do
    echo "Workspace: $workspace"
    services=$(
      kong_gateway_fetch_workspace_services_raw "$api" "$token" "$workspace"
    )
    service_names=$(echo "$services" | jq -r '.data[].name')
    for service in $service_names; do
      # Get the service data
      jq_service=$(echo "$service" | jq -R . | jq -s .)
      service_host=$(echo "$services" | jq -r ".data[] | select(.name as \$name | $jq_service | index(\$name)) | \"\(.host)\"")
      service_path=$(echo "$services" | jq -r ".data[] | select(.name as \$name | $jq_service | index(\$name)) | \"\(.path)\"")

      routes=$(
        kong_gateway_fetch_routes_raw "$api" "$token" "$workspace" "$service"
      )
      route_names=$(echo "$routes" | jq -r '.data[].name')
      for route in $route_names; do
        # Get the path data for the route
        jq_route=$(echo "$route" | jq -R . | jq -s .)
        route_path=$(echo "$routes" | jq -r ".data[] | select(.name as \$name | $jq_route | index(\$name)) | \"\(.paths[0])\"")
        summary_output+=$(
          printf '\n%s\t%s\t%s\t%s\t%s\t%s\n'  \
            "$workspace" \
            "$route" \
            "$route_path" \
            "$service" \
            "$service_host" \
            "$service_path")
      done
    done
  done
done

echo "$summary_output" | prettytable 6
