FROM dhi.io/gradle:8-jdk21-alpine-dev

# env
ENV DOCKER_TLS_CERTDIR=/certs

# pinned tool versions (override at build time with --build-arg if needed)
ARG NODE_MAJOR=22
ARG TERRAFORM_VERSION=1.9.8

# base tooling (apk is retained on the -dev DHI variant, unlike the debian-dev one)
RUN apk update && apk add --no-cache \
    bash \
    curl \
    wget \
    jq \
    git \
    gnupg \
    unzip \
    tar \
    ca-certificates \
    openssh-client-default \
    build-base \
    libffi-dev \
    openssl-dev \
    cargo \
    rust

# node.js (pinned major version) + commitlint/angular tooling
RUN apk add --no-cache nodejs-${NODE_MAJOR} npm && \
    npm i -g @commitlint/config-conventional @commitlint/cli npm@10.4.0 commitlint@14.1.0 commit-and-tag-version@12.2.0 @angular/cli standard-version

# python
RUN apk add --no-cache python3 py3-pip && \
    pip3 install --break-system-packages --upgrade setuptools

# AWS CLI (packaged natively for Alpine, no need for the glibc-only official installer) + SAM CLI
RUN apk add --no-cache aws-cli && \
    pip3 install --break-system-packages --no-cache-dir aws-sam-cli --upgrade

# docker CLI only (see docker-entrypoint.sh: this image talks to a remote/sibling
# daemon via DOCKER_HOST, it does not run dockerd itself)
RUN apk add --no-cache docker-cli

# terraform (not packaged for Alpine, install the static release binary)
RUN set -eux; \
    apkArch="$(uname -m)"; \
    case "$apkArch" in \
        x86_64) tfArch='amd64' ;; \
        aarch64) tfArch='arm64' ;; \
        armv7) tfArch='arm' ;; \
        *) echo >&2 "error: unsupported architecture ($apkArch)"; exit 1 ;; \
    esac; \
    curl -fsSLo terraform.zip "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_${tfArch}.zip"; \
    unzip terraform.zip -d /usr/bin; \
    chmod +x /usr/bin/terraform; \
    rm terraform.zip

COPY modprobe.sh /usr/local/bin/modprobe
COPY docker-entrypoint.sh /usr/local/bin/

RUN chmod +x /usr/local/bin/docker-entrypoint.sh && \
    mkdir -p /certs /certs/client && chmod 1777 /certs /certs/client

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["sh"]

# install OWASP dependency check
RUN curl -fsSLo dependency-check.zip https://github.com/jeremylong/DependencyCheck/releases/download/v6.4.1/dependency-check-6.4.1-release.zip && \
    unzip dependency-check.zip -d /opt/ && \
    rm dependency-check.zip && \
    ln -s /opt/dependency-check/bin/dependency-check.sh /usr/bin/dependency-check.sh

# pre-commit framework + IaC linting/scanning tools
RUN apk add --no-cache pre-commit && \
    pip3 install --break-system-packages --no-cache-dir checkov && \
    curl -fsSL "$(curl -fsSL https://api.github.com/repos/terraform-docs/terraform-docs/releases/latest | grep -o -E -m 1 "https://.+?-linux-amd64.tar.gz")" -o terraform-docs.tgz && tar -xzf terraform-docs.tgz terraform-docs && rm terraform-docs.tgz && chmod +x terraform-docs && mv terraform-docs /usr/bin/ && \
    curl -fsSL "$(curl -fsSL https://api.github.com/repos/tenable/terrascan/releases/latest | grep -o -E -m 1 "https://.+?_Linux_x86_64.tar.gz")" -o terrascan.tar.gz && tar -xzf terrascan.tar.gz terrascan && rm terrascan.tar.gz && mv terrascan /usr/bin/ && terrascan init && \
    curl -fsSL "$(curl -fsSL https://api.github.com/repos/terraform-linters/tflint/releases/latest | grep -o -E -m 1 "https://.+?_linux_amd64.zip")" -o tflint.zip && unzip tflint.zip && rm tflint.zip && mv tflint /usr/bin/ && \
    curl -fsSL "$(curl -fsSL https://api.github.com/repos/aquasecurity/tfsec/releases/latest | grep -o -E -m 1 "https://.+?tfsec-linux-amd64")" -o tfsec && chmod +x tfsec && mv tfsec /usr/bin/ && \
    curl -fsSL "$(curl -fsSL https://api.github.com/repos/infracost/infracost/releases/latest | grep -o -E -m 1 "https://.+?-linux-amd64.tar.gz")" -o infracost.tgz && tar -xzf infracost.tgz && rm infracost.tgz && mv infracost-linux-amd64 /usr/bin/infracost && \
    curl -fsSL "$(curl -fsSL https://api.github.com/repos/minamijoyo/tfupdate/releases/latest | grep -o -E -m 1 "https://.+?_linux_amd64.tar.gz")" -o tfupdate.tar.gz && tar -xzf tfupdate.tar.gz tfupdate && rm tfupdate.tar.gz && mv tfupdate /usr/bin/ && \
    curl -fsSL "$(curl -fsSL https://api.github.com/repos/minamijoyo/hcledit/releases/latest | grep -o -E -m 1 "https://.+?_linux_amd64.tar.gz")" -o hcledit.tar.gz && tar -xzf hcledit.tar.gz hcledit && rm hcledit.tar.gz && mv hcledit /usr/bin/
