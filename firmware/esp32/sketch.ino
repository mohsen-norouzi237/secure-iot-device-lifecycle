/*
 * =====================================================================
 *  Secure IoT Device Lifecycle — ESP32 client (Wokwi simulation)
 *
 *  - Connects to ThingsBoard over MQTT + TLS/mTLS (MQTTS)
 *  - Authenticates with an X.509 ECDSA client certificate
 *  - Publishes DHT22 temperature/humidity telemetry
 *  - Generates a 6-char challenge code (shown on the LCD) and publishes
 *    a Device Claiming request
 *
 *  Circuit:
 *    ESP32 DevKit C
 *    DHT22  -> GPIO 15
 *    LCD I2C 16x2 -> SDA GPIO 21, SCL GPIO 22 (address 0x27)
 *
 *  IMPORTANT: paste the FULL contents of your generated certificates
 *  into CA_CERT / CLIENT_CERT / CLIENT_KEY below, and set MQTT_HOST /
 *  MQTT_PORT to your Pinggy tunnel address.
 * =====================================================================
 */
#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <PubSubClient.h>
#include <DHT.h>
#include <Wire.h>
#include <LiquidCrystal_I2C.h>
#include <time.h>

const char* WIFI_SSID = "Wokwi-GUEST";
const char* WIFI_PASS = "";

// Public Pinggy tunnel address + forwarded port for the TB MQTTS broker
const char* MQTT_HOST = "XXXX.run.pinggy-free.link";
const int   MQTT_PORT = 39015;

// ---- Root CA (contents of ca.pem) ----
const char* CA_CERT = R"CA(
-----BEGIN CERTIFICATE-----
... paste the full contents of ca.pem here ...
-----END CERTIFICATE-----
)CA";

// ---- Client certificate (contents of esp32_ec.crt) ----
const char* CLIENT_CERT = R"CC(
-----BEGIN CERTIFICATE-----
... paste the full contents of esp32_ec.crt here ...
-----END CERTIFICATE-----
)CC";

// ---- Client private key (contents of esp32_ec_pkcs8.key) ----
const char* CLIENT_KEY = R"CK(
-----BEGIN PRIVATE KEY-----
... paste the full contents of esp32_ec_pkcs8.key here ...
-----END PRIVATE KEY-----
)CK";

#define DHTPIN 15
#define DHTTYPE DHT22
DHT dht(DHTPIN, DHTTYPE);
LiquidCrystal_I2C lcd(0x27, 16, 2);

WiFiClientSecure net;
PubSubClient client(net);

String claimCode;
unsigned long lastPub = 0;

String genClaimCode() {
  const char* cs = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
  String s = "";
  for (int i = 0; i < 6; i++) s += cs[random(0, 32)];
  return s;
}

void connectWifi() {
  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASS);
  lcd.clear(); lcd.print("WiFi...");
  while (WiFi.status() != WL_CONNECTED) { delay(300); Serial.print("."); }
}

void syncTime() {
  // TLS needs a valid clock to validate certificate notBefore/notAfter
  configTime(0, 0, "pool.ntp.org", "time.nist.gov");
  time_t now = time(nullptr);
  while (now < 1700000000) { delay(200); now = time(nullptr); }
}

void connectMqtt() {
  client.setBufferSize(1024);
  while (!client.connected()) {
    if (client.connect("esp32-dht-01")) {
      String p = "{\"secretKey\":\"" + claimCode + "\",\"durationMs\":600000}";
      client.publish("v1/devices/me/claim", p.c_str());
    } else {
      delay(2000);
    }
  }
}

void setup() {
  Serial.begin(115200);
  randomSeed(esp_random());
  dht.begin();
  Wire.begin(21, 22);
  lcd.init(); lcd.backlight();
  claimCode = genClaimCode();

  net.setCACert(CA_CERT);
  net.setCertificate(CLIENT_CERT);
  net.setPrivateKey(CLIENT_KEY);

  connectWifi();
  syncTime();
  client.setServer(MQTT_HOST, MQTT_PORT);
  connectMqtt();
}

void loop() {
  if (!client.connected()) connectMqtt();
  client.loop();

  if (millis() - lastPub > 5000) {
    lastPub = millis();
    float t = dht.readTemperature();
    float h = dht.readHumidity();
    if (isnan(t) || isnan(h)) return;

    char msg[96];
    snprintf(msg, sizeof(msg), "{\"temperature\":%.1f,\"humidity\":%.1f}", t, h);
    client.publish("v1/devices/me/telemetry", msg);

    lcd.clear();
    lcd.setCursor(0, 0); lcd.printf("T:%.1fC H:%.0f%%", t, h);
    lcd.setCursor(0, 1); lcd.print("Claim:"); lcd.print(claimCode);
  }
}
