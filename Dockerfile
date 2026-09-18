# syntax=docker/dockerfile:1
FROM gradle:8-jdk21-noble

# Fail a RUN if any command in a pipe fails (curl | tar, curl | bash, ...),
# not just the last one.
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# -----------------------------------------------------------------------
# Build arguments — override any of these at build time with --build-arg
# -----------------------------------------------------------------------
ARG NODE_MAJOR=24
ARG NODE_VERSION=24.21.0
ARG TERRAFORM_VERSION=1.9.8
ARG AWS_CLI_VERSION=2.36.46
ARG DEPENDENCY_CHECK_VERSION=12.1.0
ARG TERRAFORM_DOCS_VERSION=0.24.0
ARG TERRASCAN_VERSION=1.19.9
ARG TFLINT_VERSION=0.64.0
ARG TFSEC_VERSION=1.28.14
ARG INFRACOST_VERSION=0.10.45
ARG TFUPDATE_VERSION=0.10.2
ARG HCLEDIT_VERSION=0.2.18

ENV DOCKER_VERSION=29.8.1 \
    DOCKER_TLS_CERTDIR=/certs \
    DEBIAN_FRONTEND=noninteractive

# -----------------------------------------------------------------------
# Base OS packages (update + install + cache cleanup in a single layer)
# -----------------------------------------------------------------------
RUN apt-get update -y && \
    apt-get install -y --no-install-recommends \
        build-essential \
        ca-certificates \
        curl \
        git \
        gnupg \
        jq \
        libc6 \
        lsb-release \
        openssh-client \
        python3 \
        python3-pip \
        software-properties-common \
        unzip \
        wget \
    && sed -i '/hosts:/c\hosts: files dns' /etc/nsswitch.conf \
    && rm -rf /var/lib/apt/lists/*

# -----------------------------------------------------------------------
# Node.js (pinned to ${NODE_VERSION})
# -----------------------------------------------------------------------
RUN curl -fsSL https://deb.nodesource.com/setup_${NODE_MAJOR}.x | bash - && \
    apt-get install -y --no-install-recommends nodejs=${NODE_VERSION}-1nodesource1 && \
    rm -rf /var/lib/apt/lists/*

# global npm tooling
RUN npm install -g \
        npm@10.4.0 \
        @angular/cli \
        @commitlint/cli \
        @commitlint/config-conventional \
        commitlint@14.1.0 \
        commit-and-tag-version@12.2.0 \
        standard-version \
    && npm cache clean --force

# -----------------------------------------------------------------------
# Python tooling
# -----------------------------------------------------------------------
RUN pip3 install --no-cache-dir --break-system-packages --ignore-installed \
        --upgrade setuptools pre-commit checkov aws-sam-cli

# -----------------------------------------------------------------------
# AWS CLI v2 (pinned)
# -----------------------------------------------------------------------
RUN curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64-${AWS_CLI_VERSION}.zip" -o awscliv2.zip && \
    unzip -q awscliv2.zip && \
    ./aws/install && \
    rm -rf awscliv2.zip aws

# -----------------------------------------------------------------------
# Terraform (pinned binary from releases.hashicorp.com — no extra apt repo)
# -----------------------------------------------------------------------
RUN curl -fsSL "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip" -o terraform.zip && \
    unzip -q terraform.zip -d /usr/local/bin && \
    rm terraform.zip

# -----------------------------------------------------------------------
# Docker CLI static binary (pinned to ${DOCKER_VERSION})
# -----------------------------------------------------------------------
RUN set -eux; \
	apkArch="$(uname -m)"; \
	case "$apkArch" in \
		'x86_64') \
			url="https://download.docker.com/linux/static/stable/x86_64/docker-${DOCKER_VERSION}.tgz"; \
			;; \
		'armhf') \
			url="https://download.docker.com/linux/static/stable/armel/docker-${DOCKER_VERSION}.tgz"; \
			;; \
		'armv7') \
			url="https://download.docker.com/linux/static/stable/armhf/docker-${DOCKER_VERSION}.tgz"; \
			;; \
		'aarch64') \
			url="https://download.docker.com/linux/static/stable/aarch64/docker-${DOCKER_VERSION}.tgz"; \
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

# -----------------------------------------------------------------------
# OWASP Dependency-Check (pinned)
# -----------------------------------------------------------------------
RUN wget -q -O dependency-check.zip "https://github.com/jeremylong/DependencyCheck/releases/download/v${DEPENDENCY_CHECK_VERSION}/dependency-check-${DEPENDENCY_CHECK_VERSION}-release.zip" && \
    unzip -q dependency-check.zip -d /opt/ && \
    rm dependency-check.zip && \
    ln -s /opt/dependency-check/bin/dependency-check.sh /usr/bin/dependency-check.sh

# -----------------------------------------------------------------------
# Terraform ecosystem tooling — versions pinned via build args instead of
# querying the GitHub API for "latest" (rate-limited and non-reproducible)
# -----------------------------------------------------------------------
RUN curl -fsSL "https://github.com/terraform-docs/terraform-docs/releases/download/v${TERRAFORM_DOCS_VERSION}/terraform-docs-v${TERRAFORM_DOCS_VERSION}-linux-amd64.tar.gz" | tar -xzf - -C /usr/bin terraform-docs && \
    curl -fsSL "https://github.com/tenable/terrascan/releases/download/v${TERRASCAN_VERSION}/terrascan_${TERRASCAN_VERSION}_Linux_x86_64.tar.gz" | tar -xzf - -C /usr/bin terrascan && \
    terrascan init && \
    curl -fsSL "https://github.com/terraform-linters/tflint/releases/download/v${TFLINT_VERSION}/tflint_linux_amd64.zip" -o tflint.zip && \
    unzip -q tflint.zip && rm tflint.zip && mv tflint /usr/bin/ && \
    curl -fsSL "https://github.com/aquasecurity/tfsec/releases/download/v${TFSEC_VERSION}/tfsec-linux-amd64" -o /usr/bin/tfsec && \
    chmod +x /usr/bin/tfsec && \
    curl -fsSL "https://github.com/infracost/infracost/releases/download/v${INFRACOST_VERSION}/infracost-linux-amd64.tar.gz" | tar -xzf - -C /usr/bin && \
    mv /usr/bin/infracost-linux-amd64 /usr/bin/infracost && \
    curl -fsSL "https://github.com/minamijoyo/tfupdate/releases/download/v${TFUPDATE_VERSION}/tfupdate_${TFUPDATE_VERSION}_linux_amd64.tar.gz" | tar -xzf - -C /usr/bin tfupdate && \
    curl -fsSL "https://github.com/minamijoyo/hcledit/releases/download/v${HCLEDIT_VERSION}/hcledit_${HCLEDIT_VERSION}_linux_amd64.tar.gz" | tar -xzf - -C /usr/bin hcledit

# -----------------------------------------------------------------------
# Entrypoint
# -----------------------------------------------------------------------
COPY modprobe.sh /usr/local/bin/modprobe
COPY docker-entrypoint.sh /usr/local/bin/

RUN chmod +x /usr/local/bin/docker-entrypoint.sh /usr/local/bin/modprobe && \
    mkdir -p /certs/client && chmod 1777 /certs /certs/client

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["sh"]
