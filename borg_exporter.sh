#!/bin/bash

while true
do

source /borg_exporter.rc

#sleep 30

TMP_FILE=$(mktemp /tmp/prometheus-borg-XXXXX)
DATEDIFF=`which datediff`
if [ -z "$DATEDIFF" ]; then
    #ubuntu packages have a different executable name
    DATEDIFF=`which dateutils.ddiff`
fi

[ -e $TMP_FILE ] && rm -f $TMP_FILE

#prevent "Attempting to access a previously unknown unencrypted repository" prompt
export BORG_RELOCATED_REPO_ACCESS_IS_OK=yes
export BORG_UNKNOWN_UNENCRYPTED_REPO_ACCESS_IS_OK=yes
HOSTNAME=$(hostname)

function calc_bytes {
    NUM=$1
    UNIT=$2

    case "$UNIT" in
        kB)
            echo $NUM | awk '{ print $1 * 1024 }'
            ;;
        MB)
            echo $NUM | awk '{ print $1 * 1024 * 1024 }'
            ;;
        GB)
            echo $NUM | awk '{ print $1 * 1024 * 1024 * 1024 }'
            ;;
        TB)
            echo $NUM | awk '{ print $1 * 1024 * 1024 * 1024 * 1024 }'
            ;;
        B)
            echo $NUM | awk '{ print $1 }'
            ;;
    esac
}


function getBorgDataForRepository {
    REPOSITORY=$1 #repository we're looking into
    host=$2 #the host for which the backups are made

    ARCHIVES="$(BORG_PASSPHRASE=$BORG_PASSPHRASE borg list $REPOSITORY)"
    COUNTER=0
    BACKUPS_TODAY_COUNT=0

    COUNTER=$(echo "$ARCHIVES" | wc -l)
    TODAY=$(date +%Y-%m-%d)
    BACKUPS_TODAY=$(echo "$ARCHIVES" | grep ", $TODAY ")
    BACKUPS_TODAY_COUNT=$(echo -n "$BACKUPS_TODAY" | wc -l)

    #extract data for last archive
    LAST_ARCHIVE=$(BORG_PASSPHRASE=$BORG_PASSPHRASE borg list  --last 1 $REPOSITORY)
    #we need at least one valid backup to list anything meaningfull
    if [ -n "${LAST_ARCHIVE}" ]
    then
        LAST_ARCHIVE_NAME=$(echo $LAST_ARCHIVE | awk '{print $1}')
        LAST_ARCHIVE_DATE=$(echo $LAST_ARCHIVE | awk '{print $3" "$4}')
        LAST_ARCHIVE_TIMESTAMP=$(date -d "$LAST_ARCHIVE_DATE" +"%s")
        CURRENT_DATE="$(date '+%Y-%m-%d %H:%M:%S')"
        NB_HOUR_FROM_LAST_BCK=$($DATEDIFF "$LAST_ARCHIVE_DATE" "$CURRENT_DATE" -f '%H')

        # in case the date parsing from BORG didn't work (e.g. archive with space in it), datediff will output
        # a usage message on stdout and will break prometheus formatting. We need to
        # check for that here
        DATEDIFF_LINES=$(echo "$NB_HOUR_FROM_LAST_BCK" | wc -l)
        if [ "${DATEDIFF_LINES}" -eq 1 ]
        then
            
            echo "borg_hours_from_last_archive{host=\"$host\", backupserver=\"$HOSTNAME\", repo=\"$REPOSITORY\"} $NB_HOUR_FROM_LAST_BCK" >> $TMP_FILE
            
            BORG_INFO=$(BORG_PASSPHRASE="$BORG_PASSPHRASE" borg info "$REPOSITORY::$LAST_ARCHIVE_NAME")
            echo "borg_last_archive_timestamp{host=\"$host\", backupserver=\"$HOSTNAME\", repo=\"$REPOSITORY\"} $LAST_ARCHIVE_TIMESTAMP" >> $TMP_FILE
            
            TOTAL_SIZE=$(calc_bytes $(echo "$BORG_INFO" |grep "All archives" |awk '{print $3}') $(echo "$BORG_INFO" |grep "All archives" |awk '{print $4}'))
            TOTAL_SIZE_COMPRESSED=$(calc_bytes $(echo "$BORG_INFO" |grep "All archives" |awk '{print $5}') $(echo "$BORG_INFO" |grep "All archives" |awk '{print $6}'))
            TOTAL_SIZE_DEDUP=$(calc_bytes $(echo "$BORG_INFO" |grep "All archives" |awk '{print $7}') $(echo "$BORG_INFO" |grep "All archives" |awk '{print $8}'))

            
            echo "borg_total_size{host=\"$host\", backupserver=\"$HOSTNAME\", repo=\"$REPOSITORY\"} $TOTAL_SIZE" >> $TMP_FILE
            echo "borg_total_size_compressed{host=\"$host\", backupserver=\"$HOSTNAME\", repo=\"$REPOSITORY\"} $TOTAL_SIZE_COMPRESSED" >> $TMP_FILE
            echo "borg_total_size_dedup{host=\"$host\", backupserver=\"$HOSTNAME\", repo=\"$REPOSITORY\"} $TOTAL_SIZE_DEDUP" >> $TMP_FILE
        
        fi

        echo "borg_archives_count{host=\"$host\", backupserver=\"$HOSTNAME\", repo=\"$REPOSITORY\"} $COUNTER" >> $TMP_FILE
        echo "borg_archives_count_today{host=\"$host\", backupserver=\"$HOSTNAME\", repo=\"$REPOSITORY\"} $BACKUPS_TODAY_COUNT" >> $TMP_FILE

        #go through the day's archives and count the files/chunks/etc.
        
        TODAY_ARCHIVES=$(echo -n "$BACKUPS_TODAY" | awk '{print $1}' | xargs echo )
        #echo $TODAY_ARCHIVES
        if [ -n "${TODAY_ARCHIVES}" ]
        then
            for archive in $TODAY_ARCHIVES
            do
                echo "Looking at $REPOSITORY::$archive"
                #ask for an info on it
                CURRENT_INFO=$(BORG_PASSPHRASE="$BORG_PASSPHRASE" borg info "$REPOSITORY::$archive")
                #cut out something that looks like a timestamp when reporting: 20210528-1315
                readable_archive=$(echo $archive | sed -r "s/-[0-9]{8}-[0-9]{4,6}//")

                echo "borg_files_count{host=\"$host\", backupserver=\"$HOSTNAME\", repo=\"$REPOSITORY\", archive=\"$readable_archive\"} $(echo "$CURRENT_INFO" | grep "Number of files" | awk '{print $4}')" >> $TMP_FILE
                echo "borg_chunks_unique{host=\"$host\", backupserver=\"$HOSTNAME\", repo=\"$REPOSITORY\", archive=\"$readable_archive\"} $(echo "$CURRENT_INFO" | grep "Chunk index" | awk '{print $3}')" >> $TMP_FILE
                echo "borg_chunks_total{host=\"$host\", backupserver=\"$HOSTNAME\", repo=\"$REPOSITORY\", archive=\"$readable_archive\"} $(echo "$CURRENT_INFO" | grep "Chunk index" | awk '{print $4}')" >> $TMP_FILE

                # byte size
                LAST_SIZE=$(calc_bytes $(echo "$CURRENT_INFO" |grep "This archive" |awk '{print $3}') $(echo "$CURRENT_INFO" |grep "This archive" |awk '{print $4}'))
                LAST_SIZE_COMPRESSED=$(calc_bytes $(echo "$CURRENT_INFO" |grep "This archive" |awk '{print $5}') $(echo "$CURRENT_INFO" |grep "This archive" |awk '{print $6}'))
                LAST_SIZE_DEDUP=$(calc_bytes $(echo "$CURRENT_INFO" |grep "This archive" |awk '{print $7}') $(echo "$CURRENT_INFO" |grep "This archive" |awk '{print $8}'))
                
                echo "borg_last_size{host=\"$host\", backupserver=\"$HOSTNAME\", repo=\"$REPOSITORY\", archive=\"$readable_archive\"} $LAST_SIZE" >> $TMP_FILE
                echo "borg_last_size_compressed{host=\"$host\", backupserver=\"$HOSTNAME\", repo=\"$REPOSITORY\", archive=\"$readable_archive\"} $LAST_SIZE_COMPRESSED" >> $TMP_FILE
                echo "borg_last_size_dedup{host=\"$host\", backupserver=\"$HOSTNAME\", repo=\"$REPOSITORY\", archive=\"$readable_archive\"} $LAST_SIZE_DEDUP" >> $TMP_FILE
            done
        else
            echo "Unable to find any archives for today in $REPOSITORY."
        fi
    else
        echo "Unable to find any archives in $REPOSITORY. Processing skipped for it"
    fi
}

#print the definition of the metrics
echo "# HELP borg_hours_from_last_archive How many hours have passed since the last archive was added to the repo (counted by borg_exporter.sh)" >> $TMP_FILE
echo "# TYPE borg_hours_from_last_archive gauge" >> $TMP_FILE
echo "# HELP borg_last_archive_timestamp The timestamp of the last archive (unixtimestamp)" >> $TMP_FILE
echo "# TYPE borg_last_archive_timestamp gauge" >> $TMP_FILE
echo "# HELP borg_total_size The total size of all archives in the repo" >> $TMP_FILE
echo "# TYPE borg_total_size gauge" >> $TMP_FILE
echo "# HELP borg_total_size_compressed The total compressed size of all archives in the repo" >> $TMP_FILE
echo "# TYPE borg_total_size_compressed gauge" >> $TMP_FILE
echo "# HELP borg_total_size_dedup The total deduplicated size of all archives in the repo (size on disk)" >> $TMP_FILE
echo "# TYPE borg_total_size_dedup gauge" >> $TMP_FILE
echo "# HELP borg_archives_count The total number of archives in the repo" >> $TMP_FILE
echo "# TYPE borg_archives_count gauge" >> $TMP_FILE
echo "# HELP borg_archives_count_today The total number of archives created today in the repo" >> $TMP_FILE
echo "# TYPE borg_archives_count_today gauge" >> $TMP_FILE
echo "# HELP borg_files_count The number of files contained in the archive (today)" >> $TMP_FILE
echo "# TYPE borg_files_count gauge" >> $TMP_FILE
echo "# HELP borg_chunks_unique The number of unique chunks in the archive (today)" >> $TMP_FILE
echo "# TYPE borg_chunks_unique gauge" >> $TMP_FILE
echo "# HELP borg_chunks_total The total number of chunks in the archive (today)" >> $TMP_FILE
echo "# TYPE borg_chunks_total gauge" >> $TMP_FILE
echo "# HELP borg_last_size The size of the archive (today)" >> $TMP_FILE
echo "# TYPE borg_last_size gauge" >> $TMP_FILE
echo "# HELP borg_last_size_compressed The compressed size of the archive (today)" >> $TMP_FILE
echo "# TYPE borg_last_size_compressed gauge" >> $TMP_FILE
echo "# HELP borg_last_size_dedup The deduplicated size of the archive (today), (size on disk)" >> $TMP_FILE
echo "# TYPE borg_last_size_dedup gauge" >> $TMP_FILE

if [ -n "${REPOSITORY}" ] 
then
    for i in $(echo $REPOSITORY | tr ";" "\n")
    do
        echo "Use Repository: $i"
        getBorgDataForRepository "${i}" "${HOSTNAME}"
    done
else
    #discover (recursively) borg repositories starting from a path and extract info for each
    #(e.g. when running on the backup server directly)
    if [ -d "${BASEREPODIR}" ]
    then
        REPOS=`find "$BASEREPODIR" -type f -name "README" | grep -v ".cache/borg"`
        # e.g. /backup/servers/server_name/README
        for REPO in $REPOS
        do
            #cut out the /README from the name
            REPO=$(echo "$REPO" | sed -r "s/\/README//")
            #assume the name convention for the repo contains the hostname as the repo name
            # e.g. /backup/servers/server_name
            host=$(basename "$REPO")
            getBorgDataForRepository $REPO $host
        done
    else
        echo "Error: Either set REPOSITORY or BASEREPODIR in /borg_exporter.rc"
    fi
    
fi

if [ -n "${PUSHGATEWAY_URL}" ] 
then
    #send data via pushgateway
    cat $TMP_FILE | curl --data-binary @- ${PUSHGATEWAY_URL}/metrics/job/borg-exporter/host/$HOSTNAME/repository/$REPOSITORY
else
    #send data via node_exporter
    if [ -d "${NODE_EXPORTER_DIR}" ]
    then
        cp $TMP_FILE ${NODE_EXPORTER_DIR}/borg_exporter.prom
    else
        echo "Please configure either PUSHGATEWAY_URL or NODE_EXPORTER_DIR in /etc/borg_exporter.rc"
    fi
fi

#cleanup
rm -f $TMP_FILE

# Wait 10 minutes
echo "sleep 100 minutes"
sleep 6000

done
