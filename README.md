# Borg exporter

Export borg information to prometheus.

## Dependencies

 * [Dateutils](http://www.fresse.org/dateutils/)
 * Prometheus (obviously)
 * Node Exporter with textfile collector
 * [Borg](https://github.com/borgbackup/borg)

## Install

You must install this node exporter in each host that you want to monitor.

### With the Makefile

For convenience, you can install this exporter with the command line
`make install` or follow the process described in the next paragraph.

### Manually
Copy `borg_exporter.sh` to `/usr/local/bin`.

Copy `borg.env` to `/etc/borg` and replace your repokey and repository in it.

Copy the systemd unit to `/etc/systemd/system` and run 

```
systemctl enable prometheus-borg-exporter.timer
systemctl start prometheus-borg-exporter.timer
```

Alternative: Use `ExecStartPost` in your borg backupt timer itself to write our the metrics.

## Configure your node exporter

You must start the node exporter service with the following parameter: `--collector.textfile.directory=/var/lib/node_exporter/textfile_collector`

## Exported metrics

```
borg_extract_exit_code
borg_hours_from_last_backup
borg_archives_count
borg_files_count
borg_chunks_unique
borg_chunks_total
borg_last_size
borg_last_size_compressed
borg_last_size_dedup
borg_total_size
borg_total_size_compressed
borg_total_size_dedup
```

### Grafana dashboard

See [here](https://grafana.com/dashboards/7856) for a sample grafana dashboard.
