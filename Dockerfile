FROM gradle:6.6.1-jdk11
LABEL Description="ubuntu:18 + gradle:6.6.1 + jdk11 + nodejs + docker"

# env
ENV DOCKER_VERSION 20.10.8
ENV DOCKER_TLS_CERTDIR=/certs

# base operation
RUN apt-get update -y

# install nodejs
RUN curl -sL https://deb.nodesource.com/setup_14.x  | bash -
RUN apt-get install nodejs -y

# install docker
RUN apt-get install ca-certificates -y
RUN apt-get install libc6 -y
RUN apt-get install openssh-client -y
RUN sed -i '/hosts:/c\hosts: files dns' /etc/nsswitch.conf
# RUN [ -e /etc/nsswitch.conf ] && echo 'hosts: files dns' > /etc/nsswitch.conf

RUN set -eux; \
	\
	apkArch="$(uname -m)"; \
	case "$apkArch" in \
		'x86_64') \
			url='https://download.docker.com/linux/static/stable/x86_64/docker-20.10.8.tgz'; \
			;; \
		'armhf') \
			url='https://download.docker.com/linux/static/stable/armel/docker-20.10.8.tgz'; \
			;; \
		'armv7') \
			url='https://download.docker.com/linux/static/stable/armhf/docker-20.10.8.tgz'; \
			;; \
		'aarch64') \
			url='https://download.docker.com/linux/static/stable/aarch64/docker-20.10.8.tgz'; \
			;; \
		*) echo >&2 "error: unsupported architecture ($apkArch)"; exit 1 ;; \
	esac; \
	\
	wget -O docker.tgz "$url"; \
	\
	tar --extract \
		--file docker.tgz \
		--strip-components 1 \
		--directory /usr/local/bin/ \
	; \
	rm docker.tgz; \
	\
	dockerd --version; \
	docker --version

COPY modprobe.sh /usr/local/bin/modprobe
COPY docker-entrypoint.sh /usr/local/bin/

RUN mkdir /certs /certs/client && chmod 1777 /certs /certs/client
ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["sh"]

