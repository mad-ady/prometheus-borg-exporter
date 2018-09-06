.PHONY: install
install:
	@cp borg_exporter.sh /usr/local/bin/ \
	&& chmod +x /usr/local/bin/borg_exporter.sh \
	&& cp borg_exporter.rc /etc/borg_exporter.rc \
	&& cp prometheus-borg-exporter.timer /etc/systemd/system/ \
	&& cp prometheus-borg-exporter.service /etc/systemd/system/ \
	&& echo -n "Edit the config file /etc/borg_exporter.rc and press [ENTER] when finished "; read _ \
	&& systemctl enable prometheus-borg-exporter.timer \
	&& systemctl start prometheus-borg-exporter.timer
