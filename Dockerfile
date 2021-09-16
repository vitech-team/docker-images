FROM gradle:6.6.1-jdk11

# env
ENV DOCKER_VERSION 20.10.8
ENV DOCKER_TLS_CERTDIR=/certs

RUN apt-get update -y
RUN apt-get install -y unzip
RUN apt-get install -y curl
RUN apt-get install -y jq

# install nodejs
RUN curl -sL https://deb.nodesource.com/setup_14.x  | bash -
RUN apt-get install nodejs -y
RUN apt-get install build-essential -y

# install npm and angular
RUN npm install
RUN npm install -g @angular/cli

# install python
RUN apt install python3.8 python3-pip wget unzip -y

# install pip
RUN apt-get install -y python-pip
RUN pip install awscli

# install git
RUN apt-get install -y git

# install AWS
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
RUN unzip awscliv2.zip
RUN ./aws/install
RUN pip3 install aws-sam-cli --upgrade

# gradle settings
RUN export GRADLE_HOME=/opt/gradle/gradle-6.6.1
RUN export PATH=${GRADLE_HOME}/bin:${PATH}

# install terraform
RUN apt-get install -y gnupg software-properties-common curl
RUN curl -fsSL https://apt.releases.hashicorp.com/gpg | apt-key add -
RUN apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
RUN apt-get update -y
RUN apt-get install terraform

# install docker
RUN apt-get install ca-certificates -y
RUN apt-get install libc6 -y
RUN apt-get install openssh-client -y
RUN sed -i '/hosts:/c\hosts: files dns' /etc/nsswitch.conf

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
	docker --version \

COPY modprobe.sh /usr/local/bin/modprobe
COPY docker-entrypoint.sh /usr/local/bin/

RUN chmod +x /usr/local/bin/docker-entrypoint.sh

RUN mkdir /certs /certs/client && chmod 1777 /certs /certs/client
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["sh"]
