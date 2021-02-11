#!/bin/bash
#
# Implements a library of logger related functions.
# Usage
#   Add the following line to your script before using any function:
#     source [path to logger.sh]
# Style Guide
#   https://google.github.io/styleguide/shellguide.html

# Constants
readonly DATE_FORMAT='%Y-%m-%d %H:%M:%S (%Z)'

#######################################
# Echo a message using the ACTION format.
# Globals:
#   DATE_FORMAT
# Arguments:
#   Message, a text string.
# Outputs:
#   Writes message to STDOUT.
#######################################
function logger::echo_action() {
  echo ""
  echo "$(date +"$DATE_FORMAT") | ACTION - $1"
}

#######################################
# Echo a message using the ERROR format.
# Globals:
#   DATE_FORMAT
# Arguments:
#   Message, a text string.
# Outputs:
#   Writes message to STDERR.
#######################################
function logger::echo_error() {
  echo "$(date +"$DATE_FORMAT") | ERROR  - $1" >&2
}

#######################################
# Echo a message using the INFO format.
# Globals:
#   DATE_FORMAT
# Arguments:
#   Message, text string.
# Outputs:
#   Writes message to STDOUT.
#######################################
function logger::echo_info() {
  echo "$(date +"$DATE_FORMAT") | INFO   - $1"
}

#######################################
# Echo a message using the TITLE format.
# Arguments:
#   Message, a text string.
# Outputs:
#   Writes message to STDOUT.
#######################################
function logger::echo_title() {
  echo ""
  echo "###############################################################################"
  echo "$1"
  echo "###############################################################################"
}

#######################################
# Echo a message using the WARNING format.
# Arguments:
#   Message, a multi-line text string.
# Outputs:
#   Writes message to STDOUT.
#######################################
function logger::echo_warn() {
  if [[ ! -z "$1" ]]; then
    # Print each line
    echo "$1" | while read line ; do
      echo "$(date +"$DATE_FORMAT") | WARN   - ${line}"
    done
  fi
}
