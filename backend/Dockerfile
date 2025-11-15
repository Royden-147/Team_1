FROM node:18-alpine

# system deps & openssh
RUN apk add --no-cache openssh

WORKDIR /app
COPY package.json package.json
RUN npm install --production
COPY index.js .

# create dev user
RUN adduser -D dev && echo "dev:devpass" | chpasswd \
    && mkdir -p /home/dev/.ssh && chown dev:dev /home/dev/.ssh

EXPOSE 3000 22

CMD /usr/sbin/sshd && node index.js
