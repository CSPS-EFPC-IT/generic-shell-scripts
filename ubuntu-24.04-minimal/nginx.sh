#!/bin/bash
#
# Implements a library of Nginx related functions.
# Usage
#   Add the following two lines to your script before using any function:
#     source [path to logger.sh]
#     source [path to nginx.sh]
# Style Guide
#   https://google.github.io/styleguide/shellguide.html

# Functions

#######################################
# Harden Nginx Webserver settings.
# Arguments:
#   Nginx security configuration file to update, a file path.
# Outputs:
#   Writes normal log messages to STDOUT.
#   Writes error messages to STDERR.
#######################################
function nginx::harden() {
  local config_file_path="$1"

  nginx::upsert_config_file "server_tokens" "off" "${config_file_path}"
  nginx::upsert_config_file "add_header X-Frame-Options" "\"SAMEORIGIN\"" "${config_file_path}"
  nginx::upsert_config_file "add_header X-XSS-Protection" "\"1; mode=block\"" "${config_file_path}"
}

#######################################
# Update an existing and enabled parameter or insert a new parameter in an
# Nginx config file.
# Arguments:
#   1) Parameter to set, text string.
#   2) Value to set, text string.
#   3) Nginx config file to update, file path.
# Outputs:
#   Writes normal log messages to STDOUT.
#   Writes error messages to STDERR.
#######################################
function nginx::upsert_config_file() {
  local parameter="$1"
  local value="$2"
  local config_file_path="$3"

  logger::action "Setting \"${parameter}\" to \"${value}\" in ${config_file_path}..."

  # Check whether or not the parameter already exists in the configuration file.
  case $(grep -c "^[[:blank:]]*${parameter}[[:blank:]]*.*$" "${config_file_path}") in
    0)
      logger::info "Parameter not found. Inserting it before the last line..."
      sed -i "$ i\    ${parameter} ${value};" "${config_file_path}"
      ;;
    1)
      logger::info "Parameter found. Updating it..."
      # Perform substitution while maintaining code indentation.
      sed -i -E "s|^([[:blank:]]*)${parameter}([[:blank:]]*).*$|\1${parameter}\2${value};|g" "${config_file_path}"
      ;;
    *)
      logger::error "More than one line matched the search criteria. Aborting."
      exit 1
      ;;
  esac
}
