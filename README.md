# Borg exporter

Export borg information to prometheus. Extended to export information about a list of borg repositories (discovered via `find`), and also to export details about today's backups.

## Dependencies

 * [Dateutils](http://www.fresse.org/dateutils/)  `sudo apt-get install dateutils`
 * Node Exporter with textfile collector
 * [Borg](https://github.com/borgbackup/borg)
 * binutils (sed, grep, wc, etc)

## Install

### Manually
Copy `borg_exporter.sh` to `/usr/local/bin`.

Copy `borg_exporter.rc` to `/etc/` and configure it (see the configuration section below).

Copy the systemd unit and timer to `/etc/systemd/system`:
```
sudo cp prometheus-borg-exporter.* /etc/systemd/system
```
and run 

```
sudo systemctl enable prometheus-borg-exporter.timer
sudo systemctl start prometheus-borg-exporter.timer
```

Alternative: Use `ExecStartPost` in your borg backup timer itself to write our the metrics.

### Config file
The config file has a few options:
```
BORG_PASSPHRASE="mysecret"
REPOSITORY="/path/to/repository"
PUSHGATEWAY_URL=http://pushgateway.clems4ever.com
BASEREPODIR="/backup"
NODE_EXPORTER_DIR="/path/to/node/exporter/textfile/collector/dir"
```

* If you leave `BORG_PASSPHRASE=""` empty, no password will be used to access your backups
* `REPOSITORY` should either point to a valid repository (if you're running this on each server you are backing-up) or should be left empty in case you set `BASEREPODIR`
* `PUSHGATEWAY_URL` should be a valid URL for push gateway. If you're not using it, leave it blank (`PUSHGATEWAY_URL=""`) and data will be exported via node_exporter textfile collector
* `BASEREPODIR` should point to a directory on disk from where you want to search for all the repos. This makes sense when you run this exporter on the backup server, so you can access all the backups in one place. It's only taken into consideration when `REPOSITORY=""`
* `NODE_EXPORTER_DIR` should point to your node_exporter textfile collector directory (where it writes .prom files). It's used only if `PUSHGATEWAY_URL=""`


### Caveats
* The repository names shouldn't contain spaces
* The archive names shouldn't contain spaces
* The hostnames from the machines that do the export shouldn't contain spaces

### Troubleshooting
You can manually run the script with `bash -x` to get the output of intermediary commands

## Exported metrics example

```
# HELP borg_archives_count The total number of archives in the repo
# TYPE borg_archives_count gauge
borg_archives_count{backupserver="my_backup_server",host="server1",repo="/backup/server1/server1"} 3
borg_archives_count{backupserver="my_backup_server",host="server2",repo="/backup/server2/server2"} 29
# HELP borg_archives_count_today The total number of archives created today in the repo
# TYPE borg_archives_count_today gauge
borg_archives_count_today{backupserver="my_backup_server",host="server1",repo="/backup/server1/server1"} 0
borg_archives_count_today{backupserver="my_backup_server",host="server2",repo="/backup/server2/server2"} 4
# HELP borg_chunks_total The total number of chunks in the archive (today)
# TYPE borg_chunks_total gauge
borg_chunks_total{archive="_etc",backupserver="my_backup_server",host="server2",repo="/backup/server2/server2"} 11829
borg_chunks_total{archive="_home_user_scripts",backupserver="my_backup_server",host="server2",repo="/backup/server2/server2"} 11829
borg_chunks_total{archive="_usr_share_cacti",backupserver="my_backup_server",host="server2",repo="/backup/server2/server2"} 11829
borg_chunks_total{archive="mysqldump",backupserver="my_backup_server",host="server2",repo="/backup/server2/server2"} 11829
# HELP borg_chunks_unique The number of unique chunks in the archive (today)
# TYPE borg_chunks_unique gauge
borg_chunks_unique{archive="_etc",backupserver="my_backup_server",host="server2",repo="/backup/server2/server2"} 2076
borg_chunks_unique{archive="_home_user_scripts",backupserver="my_backup_server",host="server2",repo="/backup/server2/server2"} 2076
borg_chunks_unique{archive="_usr_share_cacti",backupserver="my_backup_server",host="server2",repo="/backup/server2/server2"} 2076
borg_chunks_unique{archive="_var_spool_cron",backupserver="my_backup_server",host="server2",repo="/backup/server2/server2"} 2076
borg_chunks_unique{archive="mysqldump",backupserver="my_backup_server",host="server2",repo="/backup/server2/server2"} 2076
# HELP borg_files_count The number of files contained in the archive (today)
# TYPE borg_files_count gauge
borg_files_count{archive="_etc",backupserver="my_backup_server",host="server2",repo="/backup/server2/server2"} 1030
borg_files_count{archive="_home_user_scripts",backupserver="my_backup_server",host="server2",repo="/backup/server2/server2"} 36
borg_files_count{archive="_usr_share_cacti",backupserver="my_backup_server",host="server2",repo="/backup/server2/server2"} 593
borg_files_count{archive="_var_spool_cron",backupserver="my_backup_server",host="server2",repo="/backup/server2/server2"} 1
borg_files_count{archive="mysqldump",backupserver="my_backup_server",host="server2",repo="/backup/server2/server2"} 1
# HELP borg_hours_from_last_archive How many hours have passed since the last archive was added to the repo (counted by borg_exporter.sh)
# TYPE borg_hours_from_last_archive gauge
borg_hours_from_last_archive{backupserver="my_backup_server",host="server2",repo="/backup/server2/server2"} 10
# HELP borg_last_archive_timestamp The timestamp of the last archive (unixtimestamp)
# TYPE borg_last_archive_timestamp gauge
borg_last_archive_timestamp{backupserver="my_backup_server",host="server2",repo="/backup/server2/server2"} 1.622421272e+09
# HELP borg_last_size The size of the archive (today)
# TYPE borg_last_size gauge
borg_last_size{archive="_etc",backupserver="my_backup_server",host="server2",repo="/backup/server2/server2"} 2.43479e+07
borg_last_size{archive="_home_user_scripts",backupserver="my_backup_server",host="server2",repo="/backup/server2/server2"} 146749
borg_last_size{archive="_usr_share_cacti",backupserver="my_backup_server",host="server2",repo="/backup/server2/server2"} 1.09157e+07
borg_last_size{archive="_var_spool_cron",backupserver="my_backup_server",host="server2",repo="/backup/server2/server2"} 1177.6
borg_last_size{archive="mysqldump",backupserver="my_backup_server",host="server2",repo="/backup/server2/server2"} 8.32286e+08
# HELP borg_last_size_compressed The compressed size of the archive (today)
# TYPE borg_last_size_compressed gauge
borg_last_size_compressed{archive="_etc",backupserver="my_backup_server",host="server2",repo="/backup/server2/server2"} 8.40958e+06
borg_last_size_compressed{archive="_home_user_scripts",backupserver="my_backup_server",host="server2",repo="/backup/server2/server2"} 44769.3
borg_last_size_compressed{archive="_usr_share_cacti",backupserver="my_backup_server",host="server2",repo="/backup/server2/server2"} 5.05414e+06
borg_last_size_compressed{archive="_var_spool_cron",backupserver="my_backup_server",host="server2",repo="/backup/server2/server2"} 445
borg_last_size_compressed{archive="mysqldump",backupserver="my_backup_server",host="server2",repo="/backup/server2/server2"} 5.55326e+07
# HELP borg_last_size_dedup The deduplicated size of the archive (today), (size on disk)
# TYPE borg_last_size_dedup gauge
borg_last_size_dedup{archive="_etc",backupserver="my_backup_server",host="server2",repo="/backup/server2/server2"} 608
borg_last_size_dedup{archive="_home_user_scripts",backupserver="my_backup_server",host="server2",repo="/backup/server2/server2"} 558
borg_last_size_dedup{archive="_usr_share_cacti",backupserver="my_backup_server",host="server2",repo="/backup/server2/server2"} 536
borg_last_size_dedup{archive="_var_spool_cron",backupserver="my_backup_server",host="server2",repo="/backup/server2/server2"} 548
borg_last_size_dedup{archive="mysqldump",backupserver="my_backup_server",host="server2",repo="/backup/server2/server2"} 9.81467e+06
# HELP borg_total_size The total size of all archives in the repo
# TYPE borg_total_size gauge
borg_total_size{backupserver="my_backup_server",host="server2",repo="/backup/server2/server2"} 5.35797e+09
# HELP borg_total_size_compressed The total compressed size of all archives in the repo
# TYPE borg_total_size_compressed gauge
borg_total_size_compressed{backupserver="my_backup_server",host="server2",repo="/backup/server2/server2"} 4.17637e+08
# HELP borg_total_size_dedup The total deduplicated size of all archives in the repo (size on disk)
# TYPE borg_total_size_dedup gauge
borg_total_size_dedup{backupserver="my_backup_server",host="server2",repo="/backup/server2/server2"} 1.14284e+08
```

### Grafana dashboard

See [here](https://grafana.com/dashboards/14516) for a sample grafana dashboard.
The original dashboard code is also available as `borg_backup_status_dashboard.json` in the repo.
