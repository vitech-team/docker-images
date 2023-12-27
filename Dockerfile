FROM gradle:6.8-jdk11

# env
ENV DOCKER_VERSION 20.10.8
ENV DOCKER_TLS_CERTDIR=/certs

RUN apt-get update -y
RUN apt-get install -y jq

# install certificates
RUN apt-get install ca-certificates

# install nodejs
RUN curl -sL https://deb.nodesource.com/setup_18.x  | bash - && \
    apt-get install nodejs -y && \
    apt-get install build-essential -y

# update npm
RUN npm i -g npm@latest

# install npm and angular
RUN npm install -g @angular/cli

# use npm packages instead of npx
RUN npm i -g standard-version

# install python and pip3
RUN apt-get install python3 -y && \
    apt-get install python3-pip -y && \
    pip3 install --upgrade setuptools

# install git
RUN apt-get install -y git

# install AWS
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
    unzip awscliv2.zip && \
    ./aws/install && \
    pip3 install aws-sam-cli --upgrade && \
    rm awscliv2.zip && \
    rm -r aws/

# gradle settings
RUN export GRADLE_HOME=/opt/gradle/gradle-6.8
RUN export PATH=${GRADLE_HOME}/bin:${PATH}

# Install required tools
RUN apt-get update && apt-get install -y gnupg wget lsb-release

# Install teraform
RUN wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | tee /usr/share/keyrings/hashicorp-archive-keyring.gpg
RUN echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list
RUN apt-get update && apt-get install -y terraform

# install docker
RUN apt-get install ca-certificates -y && \
    apt-get install libc6 -y && \
    apt-get install openssh-client -y && \
    sed -i '/hosts:/c\hosts: files dns' /etc/nsswitch.conf

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
	rm docker.tgz;

COPY modprobe.sh /usr/local/bin/modprobe
COPY docker-entrypoint.sh /usr/local/bin/

RUN chmod +x /usr/local/bin/docker-entrypoint.sh

RUN mkdir /certs /certs/client && chmod 1777 /certs /certs/client
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["sh"]

# install OWASP dependency check
RUN wget https://github.com/jeremylong/DependencyCheck/releases/download/v6.4.1/dependency-check-6.4.1-release.zip && \
    unzip dependency-check-6.4.1-release.zip -d /opt/ && \
    rm dependency-check-6.4.1-release.zip && \
    ln -s /opt/dependency-check/bin/dependency-check.sh /usr/bin/dependency-check.sh

RUN apt-get update -y
