#!/bin/bash
#
# Implements a library of PostgreSQL related functions.
# Usage
#   Add the following two lines to your script before using any function:
#     source [path to logger.sh]
#     source [path to postgresql.sh]
# Style Guide
#   https://google.github.io/styleguide/shellguide.html

# Constants
readonly POSTGRESQL_USER_OPTIONS_FILE_PATH="${HOME}/.pg_service.conf"
readonly POSTGRESQL_SERVICE_NAME="mydb"

# Functions

#######################################
# Create a PostgreSQL database and credentials from passed arguments.
# The database and credentials are created if not existing.
# The new database name is set to the credential username.
# The credential's password is set/reset in all cases.
# Arguments:
#   The database server FQDN, a string.
#   The database administrator's username, a string.
#   The database administrator's password, a string.
#   The new database credentials username, a string.
#   The new database credentials password, a string.
# Outputs:
#   Writes message to STDOUT.
#######################################
function postgresql::create_database_and_credentials() {

  # Parameters
  local database_server_fqdn="$1"
  local database_server_admin_username="$2"
  local database_server_admin_password="$3"
  local database_server_new_credentials_username="$4"
  local database_server_new_credentials_password="$5"

  # Variables
  local database_server_new_credentials_database="${database_server_new_credentials_username}"

  postgresql::create_user_options_file \
    "${database_server_admin_username}" \
    "${database_server_admin_password}" \
    "${database_server_fqdn}" \
    "5432" \
    "postgres"

  postgresql::create_database_if_not_exists \
    "${database_server_new_credentials_database}"

  postgresql::create_user_if_not_exists \
    "${database_server_new_credentials_username}" \
    "${database_server_new_credentials_password}"

  postgresql::set_user_password \
    "${database_server_new_credentials_username}" \
    "${database_server_new_credentials_password}"

  postgresql::grant_all_privileges \
    "${database_server_new_credentials_database}" \
    "${database_server_new_credentials_username}"

  postgresql::delete_user_options_file
}

#######################################
# Create a PostgreSQL database using passed arguments.
# Does nothing if the database already exists.
# Requires a valid PostgreSQL options file in the current user's home directory.
# Globals:
#   POSTGRESQL_SERVICE_NAME
# Arguments:
#   database: the name of the database to create
# Outputs:
#   Writes message to STDOUT.
#######################################
function postgresql::create_database_if_not_exists() {
  local database="$1"

  logger::info "Creating PostgreSQL database if not existing..."
  logger::debug "$(psql service="${POSTGRESQL_SERVICE_NAME}" << EOF
SELECT 'CREATE DATABASE "${database}" WITH ENCODING="UTF8"'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '${database}')\gexec
EOF
  )"
}

#######################################
# Create a PostgreSQL user using passed arguments.
# Requires a valid PostgreSQL options file in the current user's home directory.
# Globals:
#   POSTGRESQL_SERVICE_NAME
# Arguments:
#   username: the user's username to create
#   password: the user's password
# Outputs:
#   Writes message to STDOUT.
#######################################
function postgresql::create_user_if_not_exists() {
  local username="$1"
  local password="$2"

  logger::info 'Creating PostgreSQL database user if not existing...'
  logger::debug "$(psql service="${POSTGRESQL_SERVICE_NAME}" << EOF
SELECT 'CREATE USER "${username}" WITH ENCRYPTED PASSWORD ''${password}'''
WHERE NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname='${username}')\gexec
EOF
  )"
}

#######################################
# Create a PostgreSQL options file in the curreny user's home directory.
# Sets a named service options with passed arguments.
# Overwrites existing option file, if any.
# Globals:
#   POSTGRESQL_SERVICE_NAME
#   POSTGRESQL_USER_OPTIONS_FILE_PATH
# Arguments:
#   username: the PostgreSQL user's usename
#   password: the PostgreSQL user's password
#   host: the database server host name
#   port: the database server port number
#   database: the name of the user's default database
# Outputs:
#   Writes message to STDOUT.
#######################################
function postgresql::create_user_options_file() {
  local username="$1"
  local password="$2"
  local host="$3"
  local port="$4"
  local database="$5"

  logger::info "Creating PostgreSQL options file: ${POSTGRESQL_USER_OPTIONS_FILE_PATH}..."
  if [[ -f "${POSTGRESQL_USER_OPTIONS_FILE_PATH}" ]]; then
    logger::warn "File already exists. Overwriting content."
  else
    touch "${POSTGRESQL_USER_OPTIONS_FILE_PATH}"
  fi
  chmod 600 "${POSTGRESQL_USER_OPTIONS_FILE_PATH}"
  cat <<EOF > "${POSTGRESQL_USER_OPTIONS_FILE_PATH}"
[${POSTGRESQL_SERVICE_NAME}]
host=${host}
port=${port}
user=${username}
password=${password}
dbname=${database}
sslmode=prefer
EOF
}

#######################################
# Delete the current user's PostgreSQL options file.
# Globals:
#   POSTGRESQL_USER_OPTIONS_FILE_PATH
# Arguments:
#   None
# Outputs:
#   Writes message to STDOUT.
#######################################
function postgresql::delete_user_options_file() {

  logger::info "Deleting PostgreSQL options file: ${POSTGRESQL_USER_OPTIONS_FILE_PATH}..."
  if [[ -f "${POSTGRESQL_USER_OPTIONS_FILE_PATH}" ]]; then
    rm -f "${POSTGRESQL_USER_OPTIONS_FILE_PATH}"
  else
    logger::warn "PostgreSQL options file not found."
  fi
}

#######################################
# Grant all privileges on PostgreSQL database to a user using passed arguments.
# Requires a valid PostgreSQL options file in the current user's home directory.
# Globals:
#   POSTGRESQL_SERVICE_NAME
# Arguments:
#   database: the database that is the object of the grant
#   username: the username that should be granted privileges
# Outputs:
#   Writes message to STDOUT.
#######################################
function postgresql::grant_all_privileges() {
  local database="$1"
  local username="$2"

  logger::info "Granting all privileges on PostgreSQL database objects to user..."
  logger::debug "$(psql service="${POSTGRESQL_SERVICE_NAME}" << EOF
GRANT ALL PRIVILEGES ON DATABASE "${database}" TO "${username}";
EOF
  )"
}

#######################################
# Set a PostgreSQL user's password.
# Requires a valid PostgreSQL options file in the current user's home directory.
# Globals:
#   POSTGRESQL_SERVICE_NAME
# Arguments:
#   username: the user's username to create
#   password: the user's password
# Outputs:
#   Writes message to STDOUT.
#######################################
function postgresql::set_user_password() {
  local username="$1"
  local password="$2"

  logger::info "Setting PostgreSQL user's password..."
  logger::debug "$(psql service="${POSTGRESQL_SERVICE_NAME}" << EOF
ALTER USER "${username}" ENCRYPTED PASSWORD '${password}';
EOF
  )"
}
