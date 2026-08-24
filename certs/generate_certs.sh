#!/usr/bin/env bash
# =====================================================================
#  Local PKI generator for the Secure IoT Device Lifecycle project
#  Creates: Root CA, ThingsBoard server certificate (with SAN),
#           and an ESP32 client certificate (ECDSA / P-256).
#
#  WARNING: the generated *.key / *.p12 / *.jks files are secrets.
#           They are ignored by .gitignore and must NEVER be pushed.
# =====================================================================
set -euo pipefail

mkdir -p ~/iot-project/certs && cd ~/iot-project/certs

# ---------------------------------------------------------------------
# 1) Root CA (RSA 4096) — the Trust Anchor of the whole chain
# ---------------------------------------------------------------------
openssl genrsa -out ca.key 4096
openssl req -x509 -new -nodes -key ca.key -sha256 -days 3650 \
  -subj "/C=IR/ST=Tehran/L=Tehran/O=MyIoT/OU=Security/CN=MyIoT-Root-CA" \
  -out ca.pem

# ---------------------------------------------------------------------
# 2) ThingsBoard server certificate (RSA 2048) with SAN extension
#    SAN must include the Pinggy tunnel domains because the ESP32
#    client performs certificate hostname verification.
# ---------------------------------------------------------------------
printf '[req]\ndistinguished_name = dn\nreq_extensions = v3_req\nprompt = no\n[dn]\nC = IR\nST = Tehran\nO = MyIoT\nCN = thingsboard.local\n[v3_req]\nsubjectAltName = @alt_names\n[alt_names]\nDNS.1 = thingsboard.local\nDNS.2 = localhost\nDNS.3 = \x2a.run.pinggy-free.link\nDNS.4 = \x2a.a.pinggy.link\nDNS.5 = \x2a.pinggy.link\nIP.1 = 127.0.0.1\n' > server.ext

openssl genrsa -out server.key 2048
openssl req -new -key server.key -out server.csr -config server.ext
openssl x509 -req -in server.csr -CA ca.pem -CAkey ca.key -CAcreateserial \
  -out server.crt -days 825 -sha256 -extfile server.ext -extensions v3_req

cat server.crt ca.pem > server_chain.pem
openssl pkcs8 -topk8 -nocrypt -in server.key -out server.key.p8 && mv server.key.p8 server.key
chmod 644 *.pem *.crt *.key

# ---------------------------------------------------------------------
# 3) ESP32 client certificate (ECDSA / prime256v1)
#    RSA triggers EOF (-29312) errors in the Wokwi simulator because it
#    lacks an RSA hardware accelerator, so ECDSA P-256 is mandatory.
# ---------------------------------------------------------------------
openssl ecparam -name prime256v1 -genkey -noout -out esp32_ec.key
openssl pkcs8 -topk8 -nocrypt -in esp32_ec.key -out esp32_ec_pkcs8.key
openssl req -new -key esp32_ec.key -out esp32_ec.csr \
  -subj "/C=IR/ST=Tehran/O=MyIoT/OU=Devices/CN=esp32-dht-01"
openssl x509 -req -in esp32_ec.csr -CA ca.pem -CAkey ca.key -CAcreateserial \
  -out esp32_ec.crt -days 825 -sha256

# ---------------------------------------------------------------------
# 4) Verify the client certificate chains up to the Root CA
# ---------------------------------------------------------------------
openssl verify -CAfile ca.pem esp32_ec.crt

echo "Done. Copy ca.pem, esp32_ec.crt and esp32_ec_pkcs8.key into the ESP32 firmware."
