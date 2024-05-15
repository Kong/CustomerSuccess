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
