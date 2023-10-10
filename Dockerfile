FROM gradle:7.3.3-jdk17

# env
ENV DOCKER_VERSION 20.10.8
ENV DOCKER_TLS_CERTDIR=/certs

RUN apt-get update -y
RUN apt-get install -y jq

# install certificates
RUN apt-get install ca-certificates

# install nodejs
RUN curl -sL https://deb.nodesource.com/setup_14.x  | bash - && \
    apt-get install nodejs -y && \
    apt-get install build-essential -y

# update npm
RUN npm i -g npm@6.14.17

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
RUN export GRADLE_HOME=/opt/gradle/gradle-7.3.3
RUN export PATH=${GRADLE_HOME}/bin:${PATH}

# install teraform
RUN wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | tee /usr/share/keyrings/hashicorp-archive-keyring.gpg
RUN echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list
RUN apt-get update
RUN apt-get install terraform

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

# Install pre-commit framework
RUN apt-get install -y software-properties-common && \
    python3 -m pip install --upgrade pip && \
    pip3 install --no-cache-dir pre-commit && \
    pip3 install --no-cache-dir checkov && \
    curl -L "$(curl -s https://api.github.com/repos/terraform-docs/terraform-docs/releases/latest | grep -o -E -m 1 "https://.+?-linux-amd64.tar.gz")" > terraform-docs.tgz && tar -xzf terraform-docs.tgz terraform-docs && rm terraform-docs.tgz && chmod +x terraform-docs &&  mv terraform-docs /usr/bin/ && \
    curl -L "$(curl -s https://api.github.com/repos/tenable/terrascan/releases/latest | grep -o -E -m 1 "https://.+?_Linux_x86_64.tar.gz")" > terrascan.tar.gz && tar -xzf terrascan.tar.gz terrascan && rm terrascan.tar.gz &&  mv terrascan /usr/bin/ && terrascan init && \
    curl -L "$(curl -s https://api.github.com/repos/terraform-linters/tflint/releases/latest | grep -o -E -m 1 "https://.+?_linux_amd64.zip")" > tflint.zip && unzip tflint.zip && rm tflint.zip &&  mv tflint /usr/bin/ && \
    curl -L "$(curl -s https://api.github.com/repos/aquasecurity/tfsec/releases/latest | grep -o -E -m 1 "https://.+?tfsec-linux-amd64")" > tfsec && chmod +x tfsec &&  mv tfsec /usr/bin/ && \
    curl -L "$(curl -s https://api.github.com/repos/infracost/infracost/releases/latest | grep -o -E -m 1 "https://.+?-linux-amd64.tar.gz")" > infracost.tgz && tar -xzf infracost.tgz && rm infracost.tgz &&  mv infracost-linux-amd64 /usr/bin/infracost && \
    curl -L "$(curl -s https://api.github.com/repos/minamijoyo/tfupdate/releases/latest | grep -o -E -m 1 "https://.+?_linux_amd64.tar.gz")" > tfupdate.tar.gz && tar -xzf tfupdate.tar.gz tfupdate && rm tfupdate.tar.gz &&  mv tfupdate /usr/bin/ && \
    curl -L "$(curl -s https://api.github.com/repos/minamijoyo/hcledit/releases/latest | grep -o -E -m 1 "https://.+?_linux_amd64.tar.gz")" > hcledit.tar.gz && tar -xzf hcledit.tar.gz hcledit && rm hcledit.tar.gz &&  mv hcledit /usr/bin/

RUN apt-get update -y
