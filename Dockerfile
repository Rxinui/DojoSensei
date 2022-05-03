# FROM ubuntu:20.04

# RUN apt update && apt install curl -y
# # 0. Set env var

# # 1. Install server
# RUN curl -LOJ https://downloads.rport.io/rportd/stable/latest.php?arch=Linux_x86_64 && \
#     tar vxzf rportd_*_Linux_x86_64.tar.gz -C /usr/local/bin/ rportd && \
#     useradd -d /var/lib/rport -m -U -r -s /bin/false rport && \
#     mkdir /etc/rport/ && \
#     mkdir /var/log/rport/ && \
#     chown rport /var/log/rport/ && \
#     tar vxzf rportd_*_Linux_x86_64.tar.gz -C /etc/rport/ rportd.example.conf && \ 
#     chown -R root:rport /etc/init.d/

# # 2. Set server rportd.conf    
# COPY ./rportd.conf /etc/rport/rportd.conf
# RUN KEY_SEED=$(openssl rand -hex 18) && \
#     sed -i "s/key_seed = .*/key_seed =\"${KEY_SEED}\"/g" /etc/rport/rportd.conf

# COPY ./entrypoint.sh /entrypoint.sh
# ENTRYPOINT ["/bin/bash", "/entrypoint.sh"]

# FROM alpine:3.15 as downloader

# ARG RPORT_VERSION=0.6.0
# ARG FRONTEND_BUILD=0.6.0-build-966
# ARG NOVNC_VERSION=1.3.0

# RUN apk add unzip

# WORKDIR /app/

# RUN set -e \
#     && wget https://github.com/cloudradar-monitoring/rport/releases/download/${RPORT_VERSION}/rportd_${RPORT_VERSION}_Linux_$(uname -m).tar.gz -O rportd.tar.gz \
#     && tar xzf rportd.tar.gz rportd

# RUN set -e \
#     && wget https://downloads.rport.io/frontend/stable/rport-frontend-stable-${FRONTEND_BUILD}.zip -O frontend.zip \
#     && unzip frontend.zip -d ./frontend

# RUN set -e \
#     && wget https://github.com/novnc/noVNC/archive/refs/tags/v${NOVNC_VERSION}.zip -O novnc.zip \
#     && unzip novnc.zip && mv noVNC-${NOVNC_VERSION} ./novnc

# WORKDIR /envplate
# RUN set -e \
#     && arch=$(uname -m) \
#     && if [ "${arch}" == "aarch64" ]; then release_arch="arm64"; else release_arch=${arch}; fi \
#     && release_name=envplate_1.0.2_$(uname -s)_${release_arch}.tar.gz \
#     && wget https://github.com/kreuzwerker/envplate/releases/download/v1.0.2/${release_name} -O envplate.tar.gz \
#     && tar -xf envplate.tar.gz

# FROM ubuntu:20.04

# COPY --from=downloader /app/rportd /usr/local/bin/rportd
# COPY --from=downloader /app/frontend/ /var/www/html/
# COPY --from=downloader /app/novnc/ /var/lib/rport-novnc
# COPY --from=downloader /envplate/envplate /usr/local/bin/ep

# COPY entrypoint.sh /entrypoint.sh

# RUN set -e \
#     && useradd -d /var/lib/rport -m -U -r -s /bin/false rport \
#     && mkdir -p /etc/rport && chown rport:rport /etc/rport

# RUN  mkdir /var/log/rport/
# RUN chown -R rport:rport /var/log/rport/
# USER rport

# COPY --chown=rport:rport ./rportd.conf /etc/rport/rportd.conf

# VOLUME [ "/var/lib/rport/" ]

# # EXPOSE 8080
# # EXPOSE 3000

# ENTRYPOINT [ "/bin/bash", "/entrypoint.sh", "/usr/local/bin/rportd", "--data-dir", "/var/lib/rport", "--config", "/etc/rport/rportd.conf" ]

FROM ubuntu:20.04

ENV AUTH_USER="admin"
ENV AUTH_PASSWORD="shihan"

RUN apt update && apt install -y curl libcap2-bin
RUN apt install -y openssh-client

# RUN curl -o rportd-installer.sh https://get.rport.io
COPY ./rportd-installer.sh /rportd-installer.sh
RUN bash /rportd-installer.sh \
    --no-2fa \
    --client-port 8000 \
    --api-port 5000 \
    --fqdn localhost \
    --port-range 20000-20050

# COPY ./rportd.conf /etc/rport/rportd.conf
#1. Update rportd.conf with sed - Change the api auth by using declared <user>:<password>
##1.a Comment the database auth method
RUN sed -E -i 's/(auth_user_table\s?=\s?.*)/#\1/g' /etc/rport/rportd.conf
RUN sed -E -i 's/(auth_group_table\s?=\s?.*)/#\1/g' /etc/rport/rportd.conf
##1.b Uncomment the user/password auth method located in [api] section just before [database] and change password
RUN s_startl=`sed -n '/\[api\]/=' /etc/rport/rportd.conf` && \
    s_endl=`sed -n '/\[database\]/=' /etc/rport/rportd.conf` && \
    sed -E -i "${s_startl},${s_endl}s/(#){1,2}(auth\s?=\s?)(.*)/\2\"${AUTH_USER}:${AUTH_PASSWORD}\"/g" /etc/rport/rportd.conf

USER rport 
CMD ["rportd", "-c", "/etc/rport/rportd.conf", "--log-level", "info", "&"]
