FROM python:3.6-alpine3.8

RUN apk add --no-cache \
      bash \
      build-base \
      ca-certificates \
      cyrus-sasl-dev \
      graphviz \
      jpeg-dev \
      libffi-dev \
      libxml2-dev \
      libxslt-dev \
      openldap-dev \
      postgresql-dev \
      ttf-ubuntu-font-family \
      wget \
      patch

RUN pip install \
# gunicorn is used for launching netbox
      gunicorn \
# napalm is used for gathering information from network devices
      napalm \
# ruamel is used in startup_scripts
      ruamel.yaml \
# pinning django to the version required by netbox
# adding it here, to install the correct version of
# django-rq
      'Django>=1.11,<2.1' \
# django-rq is used for webhooks
      django-rq

WORKDIR /opt

ARG BRANCH=master
ARG URL=https://github.com/digitalocean/netbox/archive/$BRANCH.tar.gz
RUN wget -q -O - "${URL}" | tar xz \
  && mv netbox* netbox
ARG NETBOX_TOPOLOGY_URL=https://github.com/NoOne-dev/netbox_topology/archive/master.tar.gz
RUN wget -q -O - "${NETBOX_TOPOLOGY_URL}" | tar xz


WORKDIR /opt/netbox_topology-master
RUN cp -r -v netbox/ "/opt/netbox"
RUN patch -d "/opt/netbox" -b -p0 -N -r- < topology.patch

WORKDIR /opt/netbox/netbox
ARG COLLECTOR_URL=https://github.com/NoOne-dev/collector/archive/master.tar.gz
RUN wget -q -O - "${COLLECTOR_URL}" | tar xz \
  && mv collector* collector
WORKDIR /opt/netbox/netbox/collector
RUN patch "/opt/netbox/netbox/netbox/settings.py" -b -p0 -N -r- < collector.patch
RUN patch "/opt/netbox/netbox/netbox/urls.py" -b -p0 -N -r- < collector2.patch


WORKDIR /opt/netbox
RUN pip install -r requirements.txt

COPY docker/configuration.docker.py /opt/netbox/netbox/netbox/configuration.py
COPY configuration/gunicorn_config.py /etc/netbox/config/
COPY docker/nginx.conf /etc/netbox-nginx/nginx.conf
COPY docker/docker-entrypoint.sh docker-entrypoint.sh
COPY startup_scripts/ /opt/netbox/startup_scripts/
COPY initializers/ /opt/netbox/initializers/
COPY configuration/configuration.py /etc/netbox/config/configuration.py

WORKDIR /opt/netbox/netbox

ENTRYPOINT [ "/opt/netbox/docker-entrypoint.sh" ]

CMD ["gunicorn", "-c /etc/netbox/config/gunicorn_config.py", "netbox.wsgi"]

LABEL SRC_URL="$URL"

ARG NETBOX_DOCKER_PROJECT_VERSION=snapshot
LABEL NETBOX_DOCKER_PROJECT_VERSION="$NETBOX_DOCKER_PROJECT_VERSION"
