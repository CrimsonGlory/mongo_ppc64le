FROM ppc64le/ubuntu:16.04
#<We first start with the regular mongo 3.4 Dockerfile>
# add our user and group first to make sure their IDs get assigned consistently, regardless of whatever dependencies get added
# This ubuntu image is old and security.ubuntuu.com for ppc64le returns 404. We use ports instead.
RUN sed -i "s/security.ubuntu.com\/ubuntu/ports.ubuntu.com\/ubuntu-ports/g" /etc/apt/sources.list \
        && groupadd -r mongodb && useradd -r -g mongodb mongodb

RUN apt-get update \
	&& apt-get install -y --no-install-recommends \
		jq \
		numactl \
	&& rm -rf /var/lib/apt/lists/*

# grab gosu for easy step-down from root
ENV GOSU_VERSION 1.7
RUN set -x \
        && rm -vrf /var/lib/apt/lists/* \
	&& apt-get update && apt-get install -y --no-install-recommends ca-certificates wget && rm -rf /var/lib/apt/lists/* \
	&& wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$(dpkg --print-architecture)" \
	&& wget -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$(dpkg --print-architecture).asc" \
	&& export GNUPGHOME="$(mktemp -d)" \
	&& gpg --keyserver ha.pool.sks-keyservers.net --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4 \
	&& gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu \
	&& rm -r "$GNUPGHOME" /usr/local/bin/gosu.asc \
	&& chmod +x /usr/local/bin/gosu \
	&& gosu nobody true \
	&& apt-get purge -y --auto-remove ca-certificates wget

RUN mkdir /docker-entrypoint-initdb.d

# Since we have no official package for MongoDB 3.4.3 in Ubuntu or debian
# and the source zip does not come signed, we have nothing to verify.
# We are commenting htis:
#ENV GPG_KEYS \
## pub   4096R/A15703C6 2016-01-11 [expires: 2018-01-10]
##       Key fingerprint = 0C49 F373 0359 A145 1858  5931 BC71 1F9B A157 03C6
## uid                  MongoDB 3.4 Release Signing Key <packaging@mongodb.com>
#	0C49F3730359A14518585931BC711F9BA15703C6
## https://docs.mongodb.com/manual/tutorial/verify-mongodb-packages/#download-then-import-the-key-file
#RUN set -ex; \
#	export GNUPGHOME="$(mktemp -d)"; \
#	for key in $GPG_KEYS; do \
#		gpg --keyserver ha.pool.sks-keyservers.net --recv-keys "$key"; \
#	done; \
#	gpg --export $GPG_KEYS > /etc/apt/trusted.gpg.d/mongodb.gpg; \
#	rm -r "$GNUPGHOME"; \
#	apt-key list

ENV MONGO_MAJOR 3.4
ENV MONGO_VERSION 3.4.3
ENV MONGO_PACKAGE mongodb-org

ENV SCONS_MAJOR 2.5
ENV SCONS_VERSION 2.5.1

# We comment the following because mongo repo has only amd64 and i386 binaries

# RUN echo "deb http://repo.mongodb.org/apt/debian jessie/mongodb-org/$MONGO_MAJOR main" > /etc/apt/sources.list.d/mongodb-org.list

# RUN set -x \
#	&& apt-get update \
#	&& apt-get install -y \
#		${MONGO_PACKAGE}=$MONGO_VERSION \
#		${MONGO_PACKAGE}-server=$MONGO_VERSION \
#		${MONGO_PACKAGE}-shell=$MONGO_VERSION \
#		${MONGO_PACKAGE}-mongos=$MONGO_VERSION \
#		${MONGO_PACKAGE}-tools=$MONGO_VERSION \
#	&& rm -rf /var/lib/apt/lists/* \
#	&& rm -rf /var/lib/mongodb \
#	&& mv /etc/mongod.conf /etc/mongod.conf.orig

# We install the necesary tools to compile mongo on ppc64le
RUN apt-get update \
        && apt-get upgrade -y \
	&& apt-get install -y --no-install-recommends \
		unzip \
		git \
		build-essential \
		python \
		libssl-dev \
		wget \
		ca-certificates \
	&& rm -rf /var/lib/apt/lists/* \
        && wget https://downloads.sourceforge.net/project/scons/scons/${SCONS_VERSION}/scons-${SCONS_VERSION}.zip -O /tmp/scons.zip \
        && unzip /tmp/scons.zip -d /tmp/ \
        && python /tmp/scons-${SCONS_VERSION}/setup.py install \
        && wget https://fastdl.mongodb.org/src/mongodb-src-r${MONGO_VERSION}.zip -O /tmp/mongodb.zip \
        && unzip /tmp/mongodb.zip -d /tmp/ \
        && cd /tmp/mongodb-src-r${MONGO_VERSION} \
        && scons core install -j 8 -Q MONGO_VERSION=$MONGO_VERSION --ssl --prefix="/usr/" \
        && scons MONGO_VERSION=$MONGO_VERSION --clean \
	&& apt-get purge -y --auto-remove \
                ca-certificates \
                wget \
                unzip \
                git \
                build-essential \
                python \
	&& rm -rf /var/lib/apt/lists/* \
        && rm -rf /tmp/mongodb-src-r${MONGO_VERSION} \
        && rm -rf /tmp/scons-${SCONS_VERSION}/ \
        && rm -f /tmp/mongodb.zip \
        && rm -f /tmp/scons.zip
# ToDo: uninstall scons
       

RUN mkdir -p /data/db /data/configdb \
	&& chown -R mongodb:mongodb /data/db /data/configdb
VOLUME /data/db /data/configdb

COPY docker-entrypoint.sh /usr/local/bin/
# backwards compat
RUN ln -s /usr/local/bin/docker-entrypoint.sh /entrypoint.sh \
        && chmod +x /usr/local/bin/docker-entrypoint.sh \
        && chmod +x /entrypoint.sh
ENTRYPOINT ["docker-entrypoint.sh"]

EXPOSE 27017
CMD ["mongod"]
