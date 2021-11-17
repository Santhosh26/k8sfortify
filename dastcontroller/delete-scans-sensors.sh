#!/bin/bash

source ../prereq/readenv.sh ../prereq/setenv.sh
if [ ! $? -eq 0 ]; then echo "couldn't execute readenv.sh"; exit 1; fi

/opt/mssql-tools/bin/sqlcmd -S 10.96.96.1 -U sa -P $PWD_DATABASE -d edast -i delete_scans_sensors.sql

