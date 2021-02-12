#!/bin/bash
#
# Implements a library of MySQL related functions.
# Usage
#   Add the following two lines to your script before using any function:
#     source [path to logger.sh]
#     source [path to mysql.sh]
# Style Guide
#   https://google.github.io/styleguide/shellguide.html

# Constants
readonly MYSQL_USER_OPTIONS_FILE_PATH="${HOME}/.my.cnf"

# Functions

#######################################
# Create a MySQL database using passed arguments.
# Does nothing if the database already exists.
# Requires a valid MySQL options file in the current user's home directory.
# Arguments:
#   database: the name of the database to create
# Outputs:
#   Writes message to STDOUT.
#######################################
function mysql::create_database_if_not_exists() {
  local database="$1"

  logger::action "Creating MySQL database if not existing: ${database}..."
  logger::warn "$(mysql --execute "WARNINGS; CREATE DATABASE IF NOT EXISTS ${database};")"
}

#######################################
# Create a MySQL user using passed arguments.
# Resets the user password if the user already exists.
# Requires a valid MySQL options file in the current user's home directory.
# Arguments:
#   username: the user's username to create
#   password: the user's password
# Outputs:
#   Writes message to STDOUT.
#######################################
function mysql::create_user_if_not_exists() {
  local username="$1"
  local password="$2"

  logger::action "Creating MySQL database user if not existing: ${username}..."
  logger::warn "$(mysql --execute "WARNINGS; CREATE USER IF NOT EXISTS ${username} IDENTIFIED BY '${password}';")"
}

#######################################
# Create a MySQL options file in the curreny user's home directory.
# Sets [client] section options with passed arguments.
# Overwrites existing option file, if any.
# Globals:
#   MYSQL_USER_OPTIONS_FILE_PATH
# Arguments:
#   username: the MySQL user's usename
#   password: the MySQL user's password
#   host: the database server host name
#   port: the database server port number
#   database: the name of the user's default database
# Outputs:
#   Writes message to STDOUT.
#######################################
function mysql::create_user_options_file() {
  local username="$1"
  local password="$2"
  local host="$3"
  local port="$4"
  local database="$5"

  logger::action "Creating MySQL options file: ${MYSQL_USER_OPTIONS_FILE_PATH}..."
  if [[ -f "${MYSQL_USER_OPTIONS_FILE_PATH}" ]]; then
    logger::warn "File already exists. Overwriting content."
  else
    touch "${MYSQL_USER_OPTIONS_FILE_PATH}"
  fi
  chmod 400 "${MYSQL_USER_OPTIONS_FILE_PATH}"
  cat <<EOF > "${MYSQL_USER_OPTIONS_FILE_PATH}"
[client]
host="${host}"
port="${port}"
user="${username}@${host%%.*}"
password="${password}"
database="${database}"
EOF
}

#######################################
# Delete the current user's MySQL options file.
# Globals:
#   MYSQL_USER_OPTIONS_FILE_PATH
# Arguments:
#   None
# Outputs:
#   Writes message to STDOUT.
#######################################
function mysql::delete_user_options_file() {

  logger::action "Deleting MySQL options file: ${MYSQL_USER_OPTIONS_FILE_PATH}..."
  if [[ -f "${MYSQL_USER_OPTIONS_FILE_PATH}" ]]; then
    rm -f "${MYSQL_USER_OPTIONS_FILE_PATH}"
  else
    logger::warn "MySQL options file not found."
  fi
}

#######################################
# Grant all privileges on MySQL database to a user using passed arguments.
# Requires a valid MySQL options file in the current user's home directory.
# Arguments:
#   database: the database that is the object of the grant
#   username: the username that should be granted privileges
# Outputs:
#   Writes message to STDOUT.
#######################################
function mysql::grant_all_privileges() {
  local database="$1"
  local username="$2"

  logger::action "Granting all privileges on MySQL '${database}' database objects to user '${username}'..."
  logger::warn "$(mysql --execute "WARNINGS; GRANT ALL PRIVILEGES ON ${database}.* TO ${username}; FLUSH PRIVILEGES;")"
}
