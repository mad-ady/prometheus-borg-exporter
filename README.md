# Borg exporter

Export borg information to prometheus.

## Dependencies

 * [Dateutils](http://www.fresse.org/dateutils/)
 * Prometheus (obviously)
 * Node Exporter with textfile collector
 * [Borg](https://github.com/borgbackup/borg)

## Install

### With the Makfile

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

Make sure your node exporter uses `textfile` in `--collectors.enabled` and add the following parameter: `--collector.textfile.directory=/var/lib/node_exporter/textfile_collector`

## Exported metrics

```
borg_extract_exit_code
bork_hours_from_last_backup
bork_count
bork_files
bork_chunks_unique
bork_chunks_total
bork_last_size
bork_last_size_compressed
bork_last_size_dedup
bork_total_size
bork_total_size_compressed
bork_total_size_dedup
```

### Grafana dashboard

See [here](https://grafana.net/dashboards/1573) for a sample grafana dashboard.
