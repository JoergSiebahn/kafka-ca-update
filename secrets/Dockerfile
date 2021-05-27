FROM ubuntu

RUN apt-get update && apt-get -y install openssl default-jre && rm -rf /var/lib/apt/lists/*
RUN mkdir /secrets
COPY generate-ssl.sh /secrets/generate-ssl.sh
RUN chmod +x /secrets/generate-ssl.sh

VOLUME /secrets/out

WORKDIR /secrets

ENTRYPOINT ["/secrets/generate-ssl.sh"]
