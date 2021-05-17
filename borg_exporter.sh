#!/bin/bash

set -eu

TMP_FILE=$(mktemp)

[ -e $TMP_FILE ] && rm -f $TMP_FILE

HOSTNAME=$(hostname)
ARCHIVES="$(BORG_PASSPHRASE=$BORG_PASSPHRASE borg list $REPOSITORY)"
COUNTER=0


COUNTER=$(echo "$ARCHIVES" | wc -l)
LAST_ARCHIVE=$(BORG_PASSPHRASE=$BORG_PASSPHRASE borg list  --last 1 $REPOSITORY)
LAST_ARCHIVE_NAME=$(echo $LAST_ARCHIVE | awk '{print $1}')
LAST_ARCHIVE_DATE=$(echo $LAST_ARCHIVE | awk '{print $3" "$4}')
LAST_ARCHIVE_TIMESTAMP=$(date -d "$LAST_ARCHIVE_DATE" +"%s")
CURRENT_DATE="$(date '+%Y-%m-%d %H:%M:%S')"
NB_HOUR_FROM_LAST_BCK=$(datediff "$LAST_ARCHIVE_DATE" "$CURRENT_DATE" -f '%H')

# BORG_EXTRACT_EXIT_CODE=$(BORG_PASSPHRASE="$BORG_PASSPHRASE" borg extract --dry-run "$REPOSITORY::$LAST_ARCHIVE_NAME" > /dev/null 2>&1; echo $?)
BORG_INFO=$(BORG_PASSPHRASE="$BORG_PASSPHRASE" borg info "$REPOSITORY::$LAST_ARCHIVE_NAME")

echo "borg_last_archive_timestamp $LAST_ARCHIVE_TIMESTAMP" >> $TMP_FILE
# echo "borg_extract_exit_code $BORG_EXTRACT_EXIT_CODE" >> $TMP_FILE
echo "borg_hours_from_last_archive $NB_HOUR_FROM_LAST_BCK" >> $TMP_FILE
echo "borg_archives_count $COUNTER" >> $TMP_FILE
echo "borg_files_count $(echo "$BORG_INFO" | grep "Number of files" | awk '{print $4}')" >> $TMP_FILE
echo "borg_chunks_unique $(echo "$BORG_INFO" | grep "Chunk index" | awk '{print $3}')" >> $TMP_FILE
echo "borg_chunks_total $(echo "$BORG_INFO" | grep "Chunk index" | awk '{print $4}')" >> $TMP_FILE

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

# byte size
LAST_SIZE=$(calc_bytes $(echo "$BORG_INFO" |grep "This archive" |awk '{print $3}') $(echo "$BORG_INFO" |grep "This archive" |awk '{print $4}'))
LAST_SIZE_COMPRESSED=$(calc_bytes $(echo "$BORG_INFO" |grep "This archive" |awk '{print $5}') $(echo "$BORG_INFO" |grep "This archive" |awk '{print $6}'))
LAST_SIZE_DEDUP=$(calc_bytes $(echo "$BORG_INFO" |grep "This archive" |awk '{print $7}') $(echo "$BORG_INFO" |grep "This archive" |awk '{print $8}'))
TOTAL_SIZE=$(calc_bytes $(echo "$BORG_INFO" |grep "All archives" |awk '{print $3}') $(echo "$BORG_INFO" |grep "All archives" |awk '{print $4}'))
TOTAL_SIZE_COMPRESSED=$(calc_bytes $(echo "$BORG_INFO" |grep "All archives" |awk '{print $5}') $(echo "$BORG_INFO" |grep "All archives" |awk '{print $6}'))
TOTAL_SIZE_DEDUP=$(calc_bytes $(echo "$BORG_INFO" |grep "All archives" |awk '{print $7}') $(echo "$BORG_INFO" |grep "All archives" |awk '{print $8}'))


echo "borg_last_size $LAST_SIZE" >> $TMP_FILE
echo "borg_last_size_compressed $LAST_SIZE_COMPRESSED" >> $TMP_FILE
echo "borg_last_size_dedup $LAST_SIZE_DEDUP" >> $TMP_FILE
echo "borg_total_size $TOTAL_SIZE" >> $TMP_FILE
echo "borg_total_size_compressed $TOTAL_SIZE_COMPRESSED" >> $TMP_FILE
echo "borg_total_size_dedup $TOTAL_SIZE_DEDUP" >> $TMP_FILE

cat $TMP_FILE | curl --data-binary @- ${PUSHGATEWAY_URL}/metrics/job/borg-exporter/host/$HOSTNAME/repository/$REPOSITORY
