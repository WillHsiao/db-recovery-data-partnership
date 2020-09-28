#!/bin/bash
source $(pwd)/bin/config.sh
BASEDIR=$(dirname $0)

function foursquare_zipcode {
    (
        cd $BASEDIR
        NAME=foursquare_zipcode
        
        mc cp $GSHEET_CRED creds.json
        mkdir -p input && mkdir -p output

        psql $RDP_DATA -f init.sql
        
        python3 datacube.py

        if [ "$(ls -A input)" ]; then
            (
                cd input

                for file in $(ls *.tar.gz)
                do
                    max_bg_procs 5
                    (
                        echo $file

                        VERSION=${file%%.*}
                        file_name=$(tar tf $file | grep .csv.gz)
                        tar -xvzf $file $file_name -O > $VERSION.csv.gz
                        
                        gunzip -dc $VERSION.csv.gz | 
                        psql $RDP_DATA \
                            -v NAME=$NAME \
                            -v VERSION=$VERSION \
                            -f ../create_zipcode.sql
                        rm $file
                        rm $VERSION.csv.gz
                    ) &
                done
                wait
            )

            (
                cd output
                
                VERSION=$(
                    psql $RDP_DATA -At -c "
                    SELECT MAX(table_name::date) 
                    FROM information_schema.tables 
                    where table_schema = 'foursquare_zipcode'
                    AND table_name !~* 'latest|main|zipcode'"
                )

                # Export to CSV
                psql $RDP_DATA -c "\COPY (
                    SELECT * FROM $NAME.daily_zipcode
                ) TO stdout DELIMITER ',' CSV HEADER;" > foursquare_daily_zipcode.csv

                psql $RDP_DATA -c "\COPY (
                    SELECT * FROM $NAME.weekly_zipcode
                ) TO stdout DELIMITER ',' CSV HEADER;" > foursquare_weekly_zipcode.csv

                psql $RDP_DATA -c "\COPY (
                    SELECT * FROM $NAME.daily_zipcode_timeofday
                ) TO stdout DELIMITER ',' CSV HEADER;" > foursquare_daily_zipcode_timeofday.csv

                psql $RDP_DATA -c "\COPY (
                    SELECT 
                        date,
                        day_of_week,
                        year_week,
                        zipcode,
                        borough,
                        borocode,
                        category,
                        timeofday,
                        visits as visits_all,
                        avgduration,
                        medianduration,
                        pctto10mins,
                        pctto20mins,
                        pctto30mins,
                        pctto60mins,
                        pctto2hours,
                        pctto4hours,
                        pctto8hours,
                        pctover8hours
                    FROM $NAME.latest
                    WHERE demo='All'
                ) TO stdout DELIMITER ',' CSV HEADER;" > foursquare_daily_zipcode_raw.csv

                # Write VERSION info
                echo "$VERSION" > version.txt
            )
            VERSION=$(cat output/version.txt)
            Upload foursquare/$NAME $VERSION
            Upload foursquare/$NAME latest
            rm -rf input && rm -rf output
            rm creds.json
        else
            echo "the database is up-to-date!"
            rm -rf input && rm -rf output
            rm creds.json
        fi
    )
}
