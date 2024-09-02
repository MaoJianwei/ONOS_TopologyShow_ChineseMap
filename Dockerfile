# First stage is the build environment
FROM picoded/ubuntu-openjdk-8-jdk as builder
MAINTAINER Jianwei Mao <maojianwei2016@126.com>

# Set the environment variables
ENV HOME=/root
ENV BUILD_NUMBER=docker
ENV JAVA_TOOL_OPTIONS=-Dfile.encoding=UTF8

# Copy in the source
COPY . /src/onos/

# Build ONOS
# We extract the tar in the build environment to avoid having to put the tar
# in the runtime environment - this saves a lot of space
# FIXME - dependence on ONOS_ROOT and git at build time is a hack to work around
# build problems
WORKDIR /src/onos
RUN apt-get update && apt-get install -y zip wget tar && \
        wget https://repo1.maven.org/maven2/org/onosproject/onos-releases/2.5.9/onos-2.5.9.tar.gz && \
        wget https://cdn.azul.com/zulu/bin/zulu11.37.17-ca-jdk11.0.6-linux_x64.tar.gz && \
        tar zxvf onos-2.5.9.tar.gz && \
        tar zxvf zulu11.37.17-ca-jdk11.0.6-linux_x64.tar.gz && \
        sed -i 's/gui2/gui/g' ./onos-2.5.9/bin/onos-service && \
        mkdir ./onos-2.5.9/apps/org.onosproject.ONOS_Integration_Service/ && \
        cp -vrf org.onosproject.ONOS_Integration_Service.oar ./onos-2.5.9/apps/org.onosproject.ONOS_Integration_Service/ && \
        cd ./onos-2.5.9/apps/org.onosproject.ONOS_Integration_Service/ && \
        unzip org.onosproject.ONOS_Integration_Service.oar && \
        touch ./active && \
        cp -vrf ./m2/org/onosproject/* ./onos-2.5.9/apache-karaf-4.2.14/system/org/onosproject/ && \
        cd ../../../ && \
        mkdir ./onos_out/ && \
        mv ./zulu11.37.17-ca-jdk11.0.6-linux_x64/ ./onos_out/matched_jdk/ && \
        mv ./onos-2.5.9/ ./onos_out/ && \
        pwd && \
        ls -al ./onos_out/
       

# export JAVA_HOME=/home/mao/onos/current_jdk/
# export PATH=$PATH:$JAVA_HOME/bin/

# Second stage is the runtime environment
FROM adoptopenjdk/openjdk11:x86_64-ubuntu-jdk-11.0.1.13-slim

ENV JAVA_HOME=/root/onos/matched_jdk/
ENV PATH="${PATH}:${JAVA_HOME}/bin/"
ENV ONOS_APPS=gui2

# Change to /root directory
RUN     mkdir -p /root/onos
WORKDIR /root/onos

# Install ONOS
COPY --from=builder /src/onos/onos_out/ .

# Configure ONOS to log to stdout
# RUN sed -ibak '/log4j.rootLogger=/s/$/, stdout/' $(ls -d apache-karaf-*)/etc/org.ops4j.pax.logging.cfg
RUN pwd && \
        ls -al ./ && \
        find

# LABEL org.label-schema.name="ONOS" \
#       org.label-schema.description="SDN Controller" \
#       org.label-schema.usage="http://wiki.onosproject.org" \
#       org.label-schema.url="http://onosproject.org" \
#       org.label-scheme.vendor="Open Networking Foundation" \
#       org.label-schema.schema-version="1.0"

# Ports
# 6653 - OpenFlow
# 6640 - OVSDB
# 8181 - GUI
# 8101 - ONOS CLI
# 9876 - ONOS intra-cluster communication
# 22   - SSH remote control
EXPOSE 6653 6640 8181 8101 9876 22

# Get ready to run command
ENTRYPOINT ["./onos-2.5.9/bin/onos-service"]
CMD ["server"]
