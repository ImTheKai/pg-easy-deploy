# Percona Server for PostgreSQL Easy Install 
This repo provides a single click installation script for Percona Server for PostgreSQL and pg_tde. Currently we do support and test always against the latest community release of Debian/Ubuntu and Oracle Linux.


## Usage
Currently we support installing [Percona Server for PostgreSQL](https://docs.percona.com/postgresql/17/index.html) with the [pg_tde](https://percona.github.io/pg_tde/main/index.html) extension. It deploys and configures TDE with a configured database and table, that's encrypted. Ready to start your testing. 
Syntax is as follow:

```
Usage: pg-easy-deploy.sh [-h] [-v] [-l] [-t] [-d]
This tool is used to install and configure Percona Server for PostgreSQL and pg_tde for testing purposes.
Available options:
-h, --help                      Print this help and exit
-v, --verbose                   Print script debug info
-l, --logfile                   Set logfile name for script output
-t, --table                     Set table name that gets created by default
-d, --database                  Set database name that gets created by default
```
