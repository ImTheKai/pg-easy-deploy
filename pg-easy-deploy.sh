#!/bin/bash
#
#
# This script automatically installs and setups Percona Server for PostgreSQL with our pg_tde extension
# on the latest Debian/Ubuntu or Oracle Linux/RedHat release
# Please use it for development and testing environemnts only, as you should always change the password and
# security mechanism in production

set -o pipefail

#########################################
# Global Variables
#########################################
declare LOGFILE=""
declare TABLE="albums"
declare DATABASE="supersecure"

#######################################
# Show script usage info.       
#######################################
usage() {                       
  cat <<EOF             
Usage: $(basename "${BASH_SOURCE[0]}") [-h] [-v] [-l] [-t] [-d]
This tool is used to install and configure Percona Server for PostgreSQL and pg_tde for testing purposes.
Available options:      
-h, --help			Print this help and exit
-v, --verbose			Print script debug info 
-l, --logfile			Set logfile name for script output
-t, --table			Set table name that gets created by default
-d, --database			Set database name that gets created by default
EOF
  exit                  
}        

####################################### 
# Accept and parse script's params.
#######################################
parse_params() {                
while [[ $# -gt 0 ]];
  do
    arg="$1"
    case "$arg" in
    --) shift; break;;
    -l | --logfile) LOGFILE=$2
	    shift
	    ;;
    -t | --table) TABLE=$2
            shift
            ;;
    -d | --database) DATABASE=$2
            shift
            ;;
    -v | --verbose) set -x
            shift
            ;;
    -h | --help) usage
            shift
            ;;
    *)
      shift
      ;;
    esac
  done

  return 0
}       

#######################################
# Defines colours for output messages.
#######################################
setup_colors() {
  if [[ -t 2 ]] && [[ -z "${NO_COLOR-}" ]] && [[ "${TERM-}" != "dumb" ]]; then
    NOFORMAT='\033[0m' RED='\033[0;31m' GREEN='\033[0;32m' ORANGE='\033[0;33m'
    BLUE='\033[0;34m' PURPLE='\033[0;35m' CYAN='\033[0;36m' YELLOW='\033[1;33m'
  else
    NOFORMAT='' RED='' GREEN='' ORANGE='' BLUE='' PURPLE='' CYAN='' YELLOW=''
  fi
}

#######################################
# Prints message to stderr with new line at the end.
#######################################
msg() {
  echo >&2 -e "${1-}"
}

show_helper_percona() {
  echo -e ""
  echo -e "##############################################################################"
  echo -e "##############################################################################"
  echo -e "##############################################################################"
  echo -e ""
  echo -e "Percona Server for PostgreSQL and pg_tde successfully installed and configured"
  echo -e ""
  echo -e "One Database and a table were deployed with encryption turned on."
  echo -e ""
  echo -e "Database name created: $DATABASE"
  echo -e "Table name created: $TABLE"
  echo -e "WAL encryption: ON"
  echo -e ""
  echo -e "For more details take a look at our documentation: https://percona.github.io/pg_tde/main/index.html"
  echo -e ""
  echo -e "If you need support, reach out to us directly: https://www.percona.com/services/support"
  echo -e ""
  echo -e "##############################################################################"
  echo -e "##############################################################################"
  echo -e "##############################################################################"
  echo -e "
  _____                               
 |  __ \                              
 | |__) |__ _ __ ___ ___  _ __   __ _ 
 |  ___/ _ \  __/ __/ _ \| _  \ / __ |
 | |  |  __/ | | (_| (_) | | | | (_| |
 |_|   \___|_|  \___\___/|_| |_|\__,_|
"
}

#
database_and_table_create() {
  sudo -u postgres psql -U postgres -c "ALTER SYSTEM SET shared_preload_libraries ='pg_tde';"
  sudo -u postgres psql -U postgres -c "ALTER SYSTEM SET pg_tde.wal_encrypt = on;"
  if [ "$1" == "deb" ]
  then
    sudo systemctl restart postgresql
  else
    sudo systemctl restart postgresql-17
  fi	  
  sudo -u postgres psql -U postgres -c "CREATE DATABASE $DATABASE WITH OWNER=postgres;"
  sudo -u postgres psql -U postgres -d $DATABASE -c "CREATE EXTENSION pg_tde;"
  sudo -u postgres psql -U postgres -d $DATABASE -c "SELECT pg_tde_add_key_provider_file('file-vault','/tmp/pg_tde_test_keyring.per');"
  sudo -u postgres psql -U postgres -d $DATABASE -c "SELECT pg_tde_set_principal_key('test-db-master-key','file-vault');"
  sudo -u postgres psql -U postgres -d $DATABASE -c "ALTER DATABASE $DATABASE SET default_table_access_method='tde_heap';"
  sudo -u postgres psql -U postgres -c "SELECT pg_reload_conf();"
  sudo -u postgres psql -U postgres -d $DATABASE -c "CREATE TABLE $TABLE (album_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY, artist_id INTEGER, title TEXT NOT NULL, released DATE NOT NULL)"
  sudo -u postgres psql -U postgres -d $DATABASE -c "SELECT pg_tde_is_encrypted('albums');"
}

install_packages() {
  #          RH derivatives      and          Amazon Linux
if [[ -f /etc/redhat-release ]] || [[ -f /etc/system-release ]]; then
  # These are the same installation steps as you will find them here: https://percona.github.io/pg_tde/main/yum.html
  sudo dnf module disable postgresql llvm-toolset
  sudo yum -y install https://repo.percona.com/yum/percona-release-latest.noarch.rpm
  sudo percona-release setup ppg-17 -y
  sudo percona-release enable ppg-17.0 experimental -y
  sudo dnf config-manager --set-enabled ol9_codeready_builder 
  sudo yum -y install percona-postgresql-client-common percona-postgresql-common percona-postgresql-server-dev-all percona-postgresql17 percona-postgresql17-contrib percona-postgresql17-devel percona-postgresql17-libs
  sudo yum -y install percona-pg_tde_17
  sudo /usr/pgsql-17/bin/postgresql-17-setup initdb
  sudo systemctl start postgresql-17
  database_and_table_create
elif [[ -f /etc/debian_version ]]; then
  # These are the same installation steps as you will find them here: https://percona.github.io/pg_tde/main/apt.html
  sudo apt-get install -y wget gnupg2 curl lsb-release
  sudo wget https://repo.percona.com/apt/percona-release_latest.generic_all.deb
  sudo dpkg -i percona-release_latest.generic_all.deb
  sudo percona-release setup ppg-17
  sudo percona-release enable ppg-17.0 experimental
  sudo apt-get update
  sudo apt-get install -y percona-postgresql-17 percona-postgresql-contrib percona-postgresql-server-dev-all
  sudo apt-get install percona-postgresql-17-pg-tde
  database_and_table_create deb
else
  msg "${RED}ERROR: Unsupported operating system"
  exit 1
fi
}

main() {
  if [ ! -z "$LOGFILE" ]; then
    install_packages &>>${LOGFILE}
  else
    install_packages
  fi
  show_helper_percona
}

setup_colors
parse_params "${@}"
main
