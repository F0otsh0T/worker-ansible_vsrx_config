#FROM juniper/pyez-ansible:2.0.2
#FROM juniper/pyez-ansible:2.1.0
#FROM juniper/pyez-ansible:2.3.0
#FROM juniper/pyez-ansible:latest
FROM juniper/pyez-ansible@sha256:eabc68347f2df113068f942901f5f3276495dccbd94474e0bddbff147699b859

MAINTAINER Automation User <me@where.io>

LABEL type="afw-worker-cloudvsrxcnc"

ENV http_proxy="http://10.58.13.11:8080" https_proxy="http://10.58.13.11:8080"
#ENV CRYPTOGRAPHY_ALLOW_OPENSSL_102="true"

# CHANGE WORKING DIRECTORY
WORKDIR /tmp

# PORT FOR INVENTORY COMMUNICATIONS
ARG workerinit_port=5001

# INSTALL PIP
#RUN curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py &&\
RUN curl https://bootstrap.pypa.io/2.7/get-pip.py -o get-pip.py &&\
    python get-pip.py

# UPDATE AND UPGRADE
RUN apk update &&\
    apk upgrade &&\

# INSTALL BASH
    apk add bash \
# INSTALL DEV TOOLS
    build-base \
    gcc \
    make \
    libffi-dev \
# INSTALL TROUBLESHOOTING TOOLS
    curl \
    wget \
    bind-tools \
    tcpdump

# PIP INSTALL PACKAGES
COPY requirements/ /requirements/
RUN pip install --upgrade pip setuptools wheel
RUN pip install cryptography==2.8 --no-binary cryptography
#RUN pip install cryptography==3.3 --no-binary cryptography
#RUN pip install pyOpenSSL==19.1.0 --no-binary pyOpenSSL
#RUN pip install pyOpenSSL==20.0.1 --no-binary pyOpenSSL
RUN pip install --requirement /requirements/requirements.worker --no-binary :all: &&\

# WORKER-INIT_VAR REQUIREMENTS
# INSTALL FLASK
#RUN pip install Flask==1.1.1 &&\
#    pip install Flask-Cors==3.0.8 &&\
#    pip install Flask-Principal==0.4.0 &&\
#    pip install Flask-Login==0.5.0 &&\
#    pip install Flask-Mail==0.9.1 &&\
#    pip install Flask-RESTful==0.3.8 &&\
#    pip install Flask-Security==3.0.0 &&\
#    pip install Flask-SQLAlchemy==2.4.0 &&\
#    pip install Flask-BabelEx==0.9.4 &&\
#    pip install Flask-WTF==0.14.3 &&\

## INSTALL PYTHON REDIS
#    pip install redis==3.4.1 &&\

# INSTALL PYTHON PYOPENSSL
#    pip install pyOpenSSL==16.2.0 &&\
#    pip install pyOpenSSL==19.1.0 &&\

# INSTALL BCRYPT
#    pip install bcrypt==3.1.7 &&\

# INSTALL ANSIBLE 2.7.12
#    pip install ansible==2.7.12.0

# CLEAN UP
    rm -rf /requirements

# CREATE DIRECTORIES FOR ANSIBLE
RUN mkdir -p /ansible &&\
    mkdir -p /ansible/log &&\
    mkdir -p /ansible/log/config &&\
    mkdir -p /ansible/log/debug &&\
    mkdir -p /ansible/log/output &&\

# CREATE DIRECTORIES FOR CODE
    mkdir -p /afw-worker-init/common &&\
    mkdir -p /afw-worker-init/config &&\
    mkdir -p /afw-worker-init/files &&\
    mkdir -p /afw-worker-init/resources &&\

# CREATE DIRECTORIES FOR KEYS
    mkdir -p /key &&\

# CREATE DIRECTORIES FOR LOGS
    mkdir -p /var/log/automation

# COPY REPO
COPY afw-worker-init/ /afw-worker-init/
COPY jsa/ /ansible/
COPY ansible/ansible/ /ansible/
COPY ansible/files/ /files/
COPY key1/ /key/
COPY key2/ /key/
COPY license/files/ /key/

# CREATE NON-ROOT USER ON ALPINE
RUN addgroup -g 1000 -S worker &&\
    adduser -u 1000 -S worker -G worker &&\

# CHMOD & CHOWN AFW-WORKER-INIT
    chmod 744 /afw-worker-init/worker.py &&\
    chown -R worker:worker /afw-worker-init/ &&\

# CHOWN ANSIBLE
    chown -R worker:worker /ansible/ &&\

# CHMOD & CHOWN KEY
    chmod 600 /key/* &&\
    chown -R worker:worker /key/ &&\

# CHOWN LOG DIRECTORY
    chown -R worker:worker /var/log/automation/ &&\

# EMPTY PROCESS TO KEEP CONTAINER RUNNING
# COULD BE REMOVED ONCE CODE IS ACTIVELY RUNNING
    chmod 744 /files/keepalive.sh
#CMD ["/files/keepalive.sh"]

# CHANGE WORKING DIRECTORY
WORKDIR /afw-worker-init

# RUN APIGW
#CMD ["/usr/bin/python", "/afw-worker-init/broker.py.py"]
ENTRYPOINT ["/usr/bin/python", "/afw-worker-init/worker.py"]

# VERIFY REPO COPY, MODE, & PERMISSIONS
RUN ls -al /ansible/* &&\
    ls -al /files/* &&\
    ls -al /key/* &&\
    ls -al /afw-worker-init/*

ENV http_proxy="" https_proxy=""

# BECOME REGULAR USER - GOOD PRACTICE
#USER {{ USERNAME }}
USER worker

# EXPOSE APPLICATION
EXPOSE ${workerinit_port}
