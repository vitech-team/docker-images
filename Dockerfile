FROM vitechteam/ci-cd:base

RUN apt-get update -y
RUN apt-get install -y jq
# install certificates
RUN apt-get install ca-certificates
# install python and pip3
RUN apt-get install python3 -y && \
    apt-get install python3-pip -y && \
    pip3 install --upgrade setuptools
# install git
RUN apt-get install -y git

CMD ["sh"]
