#!/bin/bash
source $(pwd)/bin/config.sh
BASEDIR=$(dirname $0)
NAME=$(basename $BASEDIR)
VERSION=$DATE

(
    cd $BASEDIR
    mkdir -p output

    docker run --rm\
            -v $(pwd)/../:/recipes\
            -e NAME=$NAME\
            -w /recipes/$NAME\
            nycplanning/cook:latest python3 build.py | 
    psql $RDP_DATA -v NAME=$NAME -v VERSION=$VERSION -f create.sql

    (
        cd output

        # Export to CSV
        psql $RDP_DATA -c "\COPY (
            SELECT * FROM $NAME.\"$VERSION\"
        ) TO stdout DELIMITER ',' CSV HEADER;" > street_easy_nta.csv

        # Write VERSION info
        echo "$VERSION" > version.txt

    )
) 