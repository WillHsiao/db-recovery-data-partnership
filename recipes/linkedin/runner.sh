#!/bin/bash
source $(pwd)/bin/config.sh
BASEDIR=$(dirname $0)
NAME=$(basename $BASEDIR)
VERSION=$DATE

(
    cd $BASEDIR
    mkdir -p output
    mkdir -p input

    latest_file=$(axway_ls -nrt LinkedIn | grep .xlsx | tail -1 | awk '{print $NF}')
    echo "$latest_file"
    rm -rf input/raw.xlsx
    axway_cmd get $latest_file input/raw.xlsx

    python3 build.py |
    psql $RDP_DATA -v NAME=$NAME -v VERSION=$VERSION -f create.sql
    rm -rf input

    (
        cd output

        # Export to CSV
        psql $RDP_DATA -c "\COPY (
            SELECT * FROM linkedin.\"$VERSION\"
        ) TO stdout DELIMITER ',' CSV HEADER;" > linkedin_nyc_hiringrate.csv

        # Write VERSION info
        echo "$VERSION" > version.txt
    )
    
    Upload $NAME $VERSION
    Upload $NAME latest
    rm -rf output
)
