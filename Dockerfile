# First stage is the build environment
FROM ubuntu:18.04 AS builder
MAINTAINER Jianwei Mao <maojianwei2016@126.com>
LABEL org.opencontainers.image.authors="Jianwei Mao <maojianwei2016@126.com>"


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


RUN lscpu
RUN apt-get update && apt-get install -y git wget zip wget tar build-essential python && \
        wget https://github.com/bazelbuild/bazel/releases/download/3.7.2/bazel-3.7.2-installer-linux-x86_64.sh && \
        chmod +x bazel-3.7.2-installer-linux-x86_64.sh && \
        ./bazel-3.7.2-installer-linux-x86_64.sh && \

        git clone "https://gerrit.onosproject.org/onos" && \
        cd onos && \
        git checkout 2.5.8 && \
        
        mv ../new_for_compiling_onos/0001-support-to-add-tag-to-a-link-for-ONOS_Integration_Service.patch ./ && \
        git apply 0001-support-to-add-tag-to-a-link-for-ONOS_Integration_Service.patch && \
        git status && \
        
        mv ../new_for_compiling_onos/0002-add-the-inaccurate-china-map-AND-enable-auto-login-as-karaf-user.patch ./ && \
        git apply 0002-add-the-inaccurate-china-map-AND-enable-auto-login-as-karaf-user.patch && \
        git status && \

        mv ../new_for_compiling_onos/0003-fix-NullPointerException-for-MaoTag.patch ./ && \
        git apply 0003-fix-NullPointerException-for-MaoTag.patch && \
        git status && \
        
        mv ../new_for_compiling_onos/3001-integrate-the-app-of-ONOS_Integration_Service.patch ./ && \
        git apply 3001-integrate-the-app-of-ONOS_Integration_Service.patch && \
        git status && \

        cd apps/ && \
        git clone https://github.com/MaoJianwei/ONOS_Integration_Service.git && \
        ls -al && \
        find && \
        cd ../ && \
                
        bazel build onos && \
        cp ./bazel-bin/onos.tar.gz ../ && \
        cd ../ && \
        ls -al && \
        pwd && \
        
        wget https://cdn.azul.com/zulu/bin/zulu11.37.17-ca-jre11.0.6-linux_x64.tar.gz && \
        tar zxvf onos.tar.gz && \
        tar zxvf zulu11.37.17-ca-jre11.0.6-linux_x64.tar.gz && \
        sed -i 's/gui2/gui/g' ./onos-2.5.8/bin/onos-service && \
        
        mkdir ./onos_out/ && \
        mv ./zulu11.37.17-ca-jre11.0.6-linux_x64/ ./onos_out/matched_jdk/ && \
        mv ./onos-2.5.8/ ./onos_out/ && \
        pwd && \
        ls -al ./onos_out/


# mkdir ./onos-2.5.8/apps/org.onosproject.ONOS_Integration_Service/ && \
# cp -vrf org.onosproject.ONOS_Integration_Service.oar ./onos-2.5.8/apps/org.onosproject.ONOS_Integration_Service/ && \
# cd ./onos-2.5.8/apps/org.onosproject.ONOS_Integration_Service/ && \
# unzip org.onosproject.ONOS_Integration_Service.oar && \
# touch ./active && \
# cp -vrf ./m2/org/onosproject/* ../../apache-karaf-4.2.14/system/org/onosproject/ && \
# cd ../../../ && \

# rm -rf ./onos-2.5.8/apps/org.onosproject.gui/ && \
# rm -rf ./onos-2.5.8/apache-karaf-4.2.14/system/org/onosproject/onos-web-gui/ && \
# mkdir ./onos-2.5.8/apps/org.onosproject.gui/ && \
# cp -vrf org.onosproject.gui.oar ./onos-2.5.8/apps/org.onosproject.gui/ && \
# cd ./onos-2.5.8/apps/org.onosproject.gui/ && \
# unzip org.onosproject.gui.oar && \
# touch ./active && \
# cp -vrf ./m2/org/onosproject/* ../../apache-karaf-4.2.14/system/org/onosproject/ && \
# cd ../../../ && \

# wget https://cdn.azul.com/zulu/bin/zulu11.37.17-ca-jdk11.0.6-linux_x64.tar.gz
# tar zxvf zulu11.37.17-ca-jdk11.0.6-linux_x64.tar.gz
# mv ./zulu11.37.17-ca-jdk11.0.6-linux_x64/ ./onos_out/matched_jdk/




# export JAVA_HOME=/home/mao/onos/current_jdk/
# export PATH=$PATH:$JAVA_HOME/bin/

# Second stage is the runtime environment

FROM ubuntu:18.04
MAINTAINER Jianwei Mao <maojianwei2016@126.com>
LABEL org.opencontainers.image.authors="Jianwei Mao <maojianwei2016@126.com>"

ENV JAVA_HOME=/root/onos/matched_jdk/
ENV PATH="${PATH}:${JAVA_HOME}/bin/"
ENV ONOS_APPS=gui

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
ENTRYPOINT ["./onos-2.5.8/bin/onos-service"]
CMD ["server"]
