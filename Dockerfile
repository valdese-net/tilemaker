FROM debian:bullseye-slim
LABEL Description="Tilemaker" Version="1.4.0"

ARG DEBIAN_FRONTEND=noninteractive

# install dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      build-essential liblua5.1-0 liblua5.1-0-dev libprotobuf-dev libsqlite3-dev protobuf-compiler shapelib libshp-dev libboost-program-options-dev libboost-filesystem-dev libboost-system-dev libboost-iostreams-dev rapidjson-dev git ca-certificates

# COPY . /
WORKDIR /opt/apps

RUN git clone https://github.com/systemed/tilemaker.git && \
    cd tilemaker && \
    make && \
    make install && \
    # clean up, remove build-time only dependencies
    rm -rf /var/lib/apt/lists/* && \
    apt-get purge -y --auto-remove build-essential liblua5.1-0-dev git

ENTRYPOINT ["tilemaker"]
