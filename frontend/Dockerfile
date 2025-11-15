FROM alpine:3.19

# install nginx and openssh-server
RUN apk add --no-cache nginx openssh \
    && mkdir -p /run/nginx

# copy static site
COPY static/ /usr/share/nginx/html/

# create a test user 'dev' with password 'devpass' for SSH tests
RUN adduser -D dev && echo "dev:devpass" | chpasswd \
    && mkdir -p /home/dev/.ssh && chmod 700 /home/dev/.ssh

# configure sshd (allow password auth for testing)
RUN sed -i 's/#PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config \
    && sed -i 's/#PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config

EXPOSE 80 22

CMD /usr/sbin/sshd && nginx -g 'daemon off;'
