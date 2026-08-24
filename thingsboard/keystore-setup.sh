#!/usr/bin/env bash
# =====================================================================
#  Build the Java KeyStore (JKS) used by ThingsBoard for MQTT over TLS.
#  The PEM method is unreliable for mTLS validation in ThingsBoard, so
#  we bundle the server chain + Root CA into a JKS (KEYSTORE) instead.
#
#  Run this from the folder that holds your generated certificates.
#  Adjust the -v host path to match your machine.
# =====================================================================
set -euo pipefail

# 1) Export the server chain + private key into a PKCS#12 container
openssl pkcs12 -export -in server_chain.pem -inkey server.key -name mqttserver \
  -out mqttserver.p12 -passout pass:tbserverpass

# 2) Convert PKCS#12 -> JKS and add the Root CA as a trustedCertEntry
#    (keytool runs inside the ThingsBoard image so versions always match)
docker run --rm --user root -v "$HOME/iot-project/certs:/certs" -w /certs \
  thingsboard/tb-postgres sh -c '
    rm -f mqttserver.jks && \
    keytool -importkeystore -srckeystore mqttserver.p12 -srcstoretype PKCS12 -srcstorepass tbserverpass \
      -destkeystore mqttserver.jks -deststoretype JKS -deststorepass tbserverpass -destkeypass tbserverpass -noprompt && \
    keytool -importcert -alias rootca -trustcacerts -file ca.pem -keystore mqttserver.jks -storepass tbserverpass -noprompt && \
    keytool -list -keystore mqttserver.jks -storepass tbserverpass'

echo "mqttserver.jks created. Reference it from docker-compose.override.yml."
