# kafka-ca-update

This setup demonstrates a problem one may have with [librdkafka](https://github.com/edenhill/librdkafka)
(used with [kafkacat](https://github.com/edenhill/kafkacat) here) when CA certificates need to be
rotated.

In this case you will most likely introduce the new CA to the clients before you exchange the 
certificates on server side.
This setup provides a bundle of to certificates to demonstrate the problem. 

Two custom CAs are [generated](./secrets/generate-ssl.sh).
The first is used to sign certificates, and the second just exists as an example for the next valid
CA.
They are bundled twice.
With the first bundle, connections can be established by clients.
It has the CA certificate used by the server before the other bundle second.
At first position an unrelated CA certificate is in the bundle.
We call it the _pass-bundle_.
With the second bundle, connections can't be established by clients.
It has the CA certificate used by the server at the end and the other bundle at the beginning.
We call it the _fail-bundle_. 

The [setup with Docker Compose](./docker-compose.yml) creates all certificates, the bundles, key
stores and trust stores, starts Zookeeper and a single Kafka Broker and produces and consumes some
messages.

The producer verifies the connection directly with the valid CA certificate.
One consumer uses the _pass-bundle_.
The other consumer uses the _fail-bundle_.

## How to run the test setup?

Your machine must be able to build Docker images and to run Docker Compose, e.g. with 
[Docker Desktop](https://www.docker.com/get-started).

### Start

First start the components: 

```console
$ docker-compose up --build -d
Creating network "kafka-ca-update_default" with the default driver
Building cert-builder
…                                                                                                                                                                                                                    0.0s
 => => naming to docker.io/library/kafka-ca-update_cert-builder                                                                                                                                                                                                                                                    0.0s

Creating cert-builder ... done
Creating zookeeper    ... done
Creating kafka        ... done
Creating pass-produce ... done
Creating fail-consume ... done
Creating pass-consume ... done
```

The generated certificates can be checked in [secrets/out](./secrets/out).

### Check the logs

The _pass-consumer_ will read the produced messages _Hello_ and _World_ after a while:

```console
$ docker logs pass-consume
Hello
World
Hello
% Reached end of topic test [0] at offset 6: exiting
World
…
```

The _fail-consumer_ is not able to connect to the broker:

```console
$ docker logs fail-consume
%3|1622131073.586|SSL|rdkafka#consumer-1| [thrd:sasl_ssl://kafka:9093/bootstrap]: sasl_ssl://kafka:9093/bootstrap: crypto/rsa/rsa_pk1.c:67: error:0407008A:rsa routines:RSA_padding_check_PKCS1_type_1:invalid padding: 
%3|1622131073.586|SSL|rdkafka#consumer-1| [thrd:sasl_ssl://kafka:9093/bootstrap]: sasl_ssl://kafka:9093/bootstrap: crypto/rsa/rsa_ossl.c:662: error:04067072:rsa routines:rsa_ossl_public_decrypt:padding check failed: 
%3|1622131073.586|SSL|rdkafka#consumer-1| [thrd:sasl_ssl://kafka:9093/bootstrap]: sasl_ssl://kafka:9093/bootstrap: crypto/asn1/a_verify.c:179: error:0D0C5006:asn1 encoding routines:ASN1_item_verify:EVP lib: 
%3|1622131073.610|SSL|rdkafka#consumer-1| [thrd:sasl_ssl://kafka:9093/bootstrap]: sasl_ssl://kafka:9093/bootstrap: crypto/rsa/rsa_pk1.c:67: error:0407008A:rsa routines:RSA_padding_check_PKCS1_type_1:invalid padding: 
%3|1622131073.610|SSL|rdkafka#consumer-1| [thrd:sasl_ssl://kafka:9093/bootstrap]: sasl_ssl://kafka:9093/bootstrap: crypto/rsa/rsa_ossl.c:662: error:04067072:rsa routines:rsa_ossl_public_decrypt:padding check failed: 
%3|1622131073.610|SSL|rdkafka#consumer-1| [thrd:sasl_ssl://kafka:9093/bootstrap]: sasl_ssl://kafka:9093/bootstrap: crypto/asn1/a_verify.c:179: error:0D0C5006:asn1 encoding routines:ASN1_item_verify:EVP lib: 
%3|1622131074.764|SSL|rdkafka#consumer-1| [thrd:sasl_ssl://kafka:9093/bootstrap]: sasl_ssl://kafka:9093/bootstrap: crypto/rsa/rsa_pk1.c:67: error:0407008A:rsa routines:RSA_padding_check_PKCS1_type_1:invalid padding: 
%3|1622131074.764|SSL|rdkafka#consumer-1| [thrd:sasl_ssl://kafka:9093/bootstrap]: sasl_ssl://kafka:9093/bootstrap: crypto/rsa/rsa_ossl.c:662: error:04067072:rsa routines:rsa_ossl_public_decrypt:padding check failed: 
%3|1622131074.764|SSL|rdkafka#consumer-1| [thrd:sasl_ssl://kafka:9093/bootstrap]: sasl_ssl://kafka:9093/bootstrap: crypto/asn1/a_verify.c:179: error:0D0C5006:asn1 encoding routines:ASN1_item_verify:EVP lib: 
```

## Assumption

The _fail-consumer_ tries to verify the connection with the first CA in the _fail-bundle_.
The CA is not the one used to sign the server key and therefore the connection fails.
The consumer is not going on to try if other CAs in the bundle can verify the connection and
fails finally.

_Note:_
We realized that unrelated CAs - probably with a different CN - do not affect the connection.
That is independent of their location in the bundle.

## Expectation

The consumer tries to verify the SSL connection with all CA certificates that are available in the
bundle.
