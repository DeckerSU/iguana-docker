# syntax=docker/dockerfile:1

FROM ubuntu:18.04
LABEL maintainer="DeckerSU <deckersu@protonmail.com>"

# sudo docker run --name iguana1 --privileged --network=bridge -it --rm -e PUBKEY="03d1b38be203e9cad823bb9f1c95de19c18f000bc34bf896760d9666d8c7f6ccac" -e PASSPHRASE="YOUR_VERY_SECURE_PASSPHRASE" iguana-test /bin/bash
# cd root/dPoW/iguana
# ./m_notary_LTC or ./m_notary_3rdparty

ENV PUBKEY=
ENV PASSPHRASE=
ENV DEFAULT_RPC_USERNAME=rpcuser
ENV DEFAULT_RPC_PASSWORD=bitcoin123

RUN apt-get update && apt-get install -y \
        iproute2 \
        netcat \
        iptables \
        iputils-ping \
        dnsutils \
        curl \
        git \
        clang \
        cmake \
        libcurl4-gnutls-dev \
        libsodium-dev \
        libssl-dev \
        zlib1g-dev \
        jq \
    && rm -rf /var/lib/apt/lists/*
RUN cd $HOME && git clone https://github.com/KomodoPlatform/dPoW
RUN cd $HOME && git clone https://github.com/nanomsg/nanomsg && cd nanomsg && cmake . -DNN_TESTS=OFF -DNN_ENABLE_DOC=OFF && make -j$(nproc --all) && make install && ldconfig
RUN cd $HOME/dPoW/iguana && ./m_notary_build 
RUN echo "$HOME" > $HOME/dPoW/iguana/userhome.txt \
    && echo "curl --url \"http://127.0.0.1:7776\" --data \"{\\\"method\\\":\\\"walletpassphrase\\\",\\\"params\\\":[\\\"\$PASSPHRASE\\\", 9999999]}\"" > $HOME/dPoW/iguana/wp_7776 && chmod +x $HOME/dPoW/iguana/wp_7776 \
    && echo "curl --url \"http://127.0.0.1:7779\" --data \"{\\\"method\\\":\\\"walletpassphrase\\\",\\\"params\\\":[\\\"\$PASSPHRASE\\\", 9999999]}\"" > $HOME/dPoW/iguana/wp_7779 && chmod +x $HOME/dPoW/iguana/wp_7779 \
    && echo "pubkey=\$PUBKEY" > $HOME/dPoW/iguana/pubkey.txt
ADD entrypoint.sh /sbin/
ENTRYPOINT ["/sbin/entrypoint.sh"]

# CMD ["bash"]
# ENTRYPOINT ["/bin/ping"]
# CMD ["-c", "1", "google.com"]


