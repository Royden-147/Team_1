FROM postgres:15

RUN apt-get update && apt-get install -y openssh-server && rm -rf /var/lib/apt/lists/*

# create dev user for SSH access (not postgres user)
RUN useradd -m -s /bin/bash dev && echo "dev:devpass" | chpasswd

# configure sshd
RUN mkdir -p /var/run/sshd

EXPOSE 5432 22

# postgres entrypoint already handles DB startup
# we use original entrypoint. SSHD will be started via a small wrapper
COPY docker-entrypoint-wrapper.sh /usr/local/bin/entrypoint-wrapper.sh
RUN chmod +x /usr/local/bin/entrypoint-wrapper.sh

ENTRYPOINT ["/usr/local/bin/entrypoint-wrapper.sh"]
CMD ["postgres"]
