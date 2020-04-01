FROM golang:1.14.1 AS builder

ENV DOCKER_GEN_VERSION 0.7.4
ENV FOREGO_VERSION 20180216151118

# Get and compile docker-gen
RUN git clone --branch $DOCKER_GEN_VERSION https://github.com/jwilder/docker-gen.git src/github.com/jwilder/docker-gen \
 && make -C src/github.com/jwilder/docker-gen  get-deps \
 && make -C src/github.com/jwilder/docker-gen

# Get and compile forego
RUN git clone --branch $FOREGO_VERSION https://github.com/ddollar/forego.git src/github.com/ddollar/forego \
 && make -C src/github.com/ddollar/forego -e BIN=/go/bin/forego


FROM nginx:1.17.8
LABEL maintainer="Jason Wilder mail@jasonwilder.com"

# Install/updates certificates
RUN apt-get update \
 && apt-get install -y -q --no-install-recommends ca-certificates \
 && apt-get clean \
 && rm -r /var/lib/apt/lists/*

# Configure Nginx and apply fix for very long server names
RUN echo "daemon off;" >> /etc/nginx/nginx.conf \
 && sed -i 's/worker_processes  1/worker_processes  auto/' /etc/nginx/nginx.conf

# Install docker-gen and forego
COPY --from=builder /go/src/github.com/jwilder/docker-gen/docker-gen /usr/local/bin/
COPY --from=builder /go/bin/forego /usr/local/bin/forego
RUN chmod u+x /usr/local/bin/docker-gen /usr/local/bin/forego

COPY network_internal.conf /etc/nginx/

COPY . /app/
WORKDIR /app/

ENV DOCKER_HOST unix:///tmp/docker.sock

VOLUME ["/etc/nginx/certs", "/etc/nginx/dhparam"]

ENTRYPOINT ["/app/docker-entrypoint.sh"]
CMD ["forego", "start", "-r"]
