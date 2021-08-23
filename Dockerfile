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
RUN apt-get install build-essential -y

# install python
RUN apt install python3.8 python3-pip wget unzip -y

# install AWS
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
RUN unzip awscliv2.zip
RUN ./aws/install
RUN pip3 install aws-sam-cli --upgrade

# gradle settings
RUN export GRADLE_HOME=/opt/gradle/gradle-6.6.1
RUN export PATH=${GRADLE_HOME}/bin:${PATH}

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

# install go
RUN wget https://dl.google.com/go/go1.13.linux-amd64.tar.gz
RUN sha256sum go1.13.linux-amd64.tar.gz
RUN tar -C /usr/local -xzf go1.13.linux-amd64.tar.gz
RUN export PATH=$PATH:/usr/local/go/bin
RUN /bin/bash -c "source ~/.profile"


