#!/bin/bash

PASS="qwerty123"

echo "Cleaning up"
rm ./out/demo-ca-1.key
rm ./out/demo-ca-2.key
rm ./out/unrelated-ca.key
rm ./out/demo-ca-1.pem
rm ./out/demo-ca-2.pem
rm ./out/unrelated-ca.pem
rm ./out/demo-ca-1.srl
rm ./out/pass-bundle.pem
rm ./out/fail-bundle.pem
rm ./out/kafka.keystore.jks
rm ./out/kafka.truststore.jks
rm ./out/kafka-ca1-signed.pem
rm ./out/sslkey_creds
rm ./out/keystore_creds
rm ./out/truststore_creds

# Generate CA key
openssl req -new -x509 -keyout ./out/demo-ca-1.key -out ./out/demo-ca-1.pem -days 365 \
  -subj '/CN=demo/OU=Demo/O=Demo Org/L=Hamburg/C=DE' \
  -passin pass:${PASS} -passout pass:${PASS}

# Generate a second CA key
openssl req -new -x509 -keyout ./out/demo-ca-2.key -out ./out/demo-ca-2.pem -days 365 \
  -subj '/CN=demo/OU=Demo/O=Demo Org/L=Hamburg/C=DE' \
  -passin pass:${PASS} -passout pass:${PASS}

# Generate an unrelated CA key
openssl req -new -x509 -keyout ./out/unrelated-ca.key -out ./out/unrelated-ca.pem -days 365 \
  -subj '/CN=unrelated/OU=Demo/O=Demo Org/L=Hamburg/C=DE' \
  -passin pass:${PASS} -passout pass:${PASS}

echo "Creating CA bundles"

cat ./out/unrelated-ca.pem ./out/demo-ca-1.pem ./out/demo-ca-2.pem > ./out/pass-bundle.pem
cat ./out/demo-ca-2.pem ./out/demo-ca-1.pem > ./out/fail-bundle.pem


echo "Creating keystore"
keytool -genkey -noprompt \
       -alias kafka \
       -dname "CN=kafka, OU=Demo, O=Demo Org, L=Hamburg, C=DE" \
       -keystore ./out/kafka.keystore.jks \
       -keyalg RSA \
       -storepass ${PASS} \
       -keypass ${PASS}


echo "Creating CSR"
keytool -certreq -noprompt -keystore ./out/kafka.keystore.jks \
  -alias kafka \
  -file kafka.csr \
  -storepass ${PASS} -keypass ${PASS}

echo "Signing key with CA-1"
openssl x509 -req -CA ./out/demo-ca-1.pem \
  -CAkey ./out/demo-ca-1.key \
  -in kafka.csr \
  -out ./out/kafka-ca1-signed.pem \
  -days 7200 \
  -CAcreateserial \
  -passin pass:${PASS}

echo "Import CA into keystore"
keytool -noprompt -keystore ./out/kafka.keystore.jks -alias CARoot \
  -import -file ./out/demo-ca-1.pem \
  -storepass ${PASS} -keypass ${PASS}

echo "Import signed cert into keystore"
keytool -noprompt -keystore ./out/kafka.keystore.jks -alias kafka \
  -import -file ./out/kafka-ca1-signed.pem \
  -storepass ${PASS} -keypass ${PASS}

echo "Create truststore and import the CA-1 cert"
keytool -noprompt -keystore ./out/kafka.truststore.jks -alias CARoot \
  -import -file ./out/demo-ca-1.pem \
  -storepass ${PASS} -keypass ${PASS}

echo "${PASS}" > ./out/sslkey_creds
echo "${PASS}" > ./out/keystore_creds
echo "${PASS}" > ./out/truststore_creds

sleep 2
