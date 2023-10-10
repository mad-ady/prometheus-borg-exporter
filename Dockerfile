FROM debian:12

RUN apt-get update && \
    apt-get install -y dateutils binutils borgbackup openssh-client && \
    apt-get clean

COPY borg_exporter.rc borg_exporter.sh /

# Authorize SSH Host
RUN mkdir -p /root/.ssh && \
    chmod 0700 /root/.ssh

# See: https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/githubs-ssh-key-fingerprints
COPY known_hosts /root/.ssh/known_hosts

# Add the Keys
COPY id_rsa id_rsa.pub /root/.ssh/

# Set permissions
RUN chmod 600 /root/.ssh/id_rsa && \
    chmod 600 /root/.ssh/id_rsa.pub

CMD ["/borg_exporter.sh"]
