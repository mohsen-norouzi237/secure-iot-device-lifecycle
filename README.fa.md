# 🔐 چرخهٔ امن عمر دستگاه اینترنت اشیاء با ThingsBoard و mTLS

<div dir="rtl">

> پیاده‌سازی چرخهٔ امن عمر یک دستگاه اینترنت اشیاء: ارتباط MQTT روی TLS/mTLS با
> گواهی‌های X.509، زیرساخت کلید عمومی (PKI) محلی با OpenSSL، ثبت خودکار
> دستگاه (Auto-Provisioning) و دراختیارگیری دستگاه (Device Claiming) روی سکوی
> ThingsBoard — با یک دستگاه ESP32 شبیه‌سازی‌شده در Wokwi.

🌐 **زبان‌ها:** فارسی (همین فایل) · [English / انگلیسی](./README.md)

---

## 📖 معرفی پروژه

این پروژه بخشی از **چرخهٔ امن عمر یک دستگاه اینترنت اشیاء** را پیاده‌سازی می‌کند؛ از
ارتباط امن و احراز هویت تا انتقال مالکیت. در این سناریو یک برد شبیه‌سازی‌شدهٔ
**ESP32** (شامل حسگر دما و رطوبت و یک نمایشگر LCD) از طریق **MQTT روی TLS** به سکوی
**ThingsBoard** متصل می‌شود، با یک **گواهی X.509 (mTLS)** خود را احراز هویت می‌کند،
به‌صورت خودکار ثبت می‌شود و در نهایت با فرایند Device Claiming به یک کاربر نهایی
اختصاص می‌یابد.


---

## ✨ ویژگی‌های اصلی

- زیرساخت کلید عمومی محلی با OpenSSL — یک Root CA خودامضا که گواهی سرور و کلاینت را امضا می‌کند.
- ارتباط MQTT روی TLS و mTLS — تونل رمزنگاری‌شده به همراه احراز هویت دوطرفهٔ گواهی.
- احراز هویت X.509 — دستگاه با یک گواهی کلاینت **ECDSA (P-256)** هویت خود را اثبات می‌کند و کلید خصوصی هرگز از دستگاه خارج نمی‌شود.
- ثبت خودکار (Auto-Provisioning) — دستگاه‌های جدید با استراتژی «X.509 Certificate Chain» در اولین اتصال امن ثبت می‌شوند.
- دراختیارگیری دستگاه (Device Claiming) — انتقال امن مالکیت به مشتری با یک کد چالش زمان‌دار که روی LCD نمایش داده می‌شود.
- تحلیل امنیتی — مقایسهٔ ملموس با روش سادهٔ «MQTT + Access Token» (شنود، سرقت اعتبارنامه، جعل هویت، حملهٔ مرد میانی و Replay).

---

## 🧱 معماری سامانه

زنجیرهٔ اعتماد (Chain of Trust) به این صورت است:

</div>

```text
            ┌──────────────────────────┐
            │        Root CA           │   (Trust Anchor)
            └────────────┬─────────────┘
          ┌─────────────┴─────────────────┐
          ▼                               ▼
  ┌────────────────┐   MQTTS /       ┌────────────────┐
  │  ESP32 (Wokwi) │──mTLS (Pinggy)──│  ThingsBoard   │
  │  DHT22 + LCD   │                 │  Docker :8883  │
  └────────────────┘                 └────────────────┘
     client cert (ECDSA)             server cert (RSA + SAN)
```

<div dir="rtl">

- مرجع صدور گواهی (Root CA) — لنگر اعتماد؛ هر دو گواهی سرور و کلاینت توسط آن امضا شده‌اند.
- سرور ThingsBoard — با یک گواهی سرور که از یک Java KeyStore بارگذاری می‌شود، اصالت خود را به کلاینت اثبات می‌کند.
- برد ESP32 (Wokwi) — با یک گواهی کلاینت ECDSA اصالت خود را اثبات می‌کند (استفاده از ECDSA از بروز Timeout در شبیه‌ساز جلوگیری می‌کند).
- تونل ارتباطی Pinggy — ترافیک رمزنگاری‌شدهٔ لایهٔ ۴ را بدون پایان‌دادن به رمزنگاری، به پورت داخلی 8883 هدایت می‌کند.

---

## 🗂️ ساختار مخزن (Repository)

</div>

```text
secure-iot-device-lifecycle/
├── README.md                        # مستندات انگلیسی
├── README.fa.md                     # مستندات فارسی (همین فایل)
├── LICENSE                          # مجوز MIT
├── .gitignore                       # کلیدهای خصوصی را حذف می‌کند
│
├── certs/
│   ├── generate_certs.sh            # OpenSSL: Root CA + server + client
│   └── .gitkeep
│
├── thingsboard/
│   ├── docker-compose.override.yml  # فعال‌سازی MQTT روی TLS
│   └── keystore-setup.sh            # ساخت mqttserver.jks
│
├── firmware/
│   └── esp32/
│       ├── sketch.ino               # کد ESP32 (mTLS + telemetry + claiming)
│       ├── diagram.json             #  مدار Wokwi
│       └── libraries.txt            # کتابخانه‌های Wokwi
│
└── docs/
    └── images/                      #تصاویر و اسکرین‌شات‌ها
```

<div dir="rtl">


---

## 🚀 راه‌اندازی قدم‌به‌قدم

**۱) راه‌اندازی ThingsBoard با Docker**، مطابق مستندات رسمی یک نمونه را بالا بیاورید.

**۲) ساخت زیرساخت گواهی (PKI):**

</div>

```bash
cd certs
chmod +x generate_certs.sh
./generate_certs.sh
```

<div dir="rtl">

در این مرحله گواهی ریشه (`ca.pem`)، گواهی سرور به همراه افزونهٔ SAN، و گواهی
کلاینت ECDSA برای ESP32 ساخته می‌شوند.

**۳) فعال‌سازی MQTT روی TLS در ThingsBoard:**

</div>

```bash
cd ../thingsboard
chmod +x keystore-setup.sh
./keystore-setup.sh                 # ساخت mqttserver.jks
docker compose up -d --force-recreate mytb
```

<div dir="rtl">

**۴) برقراری تونل Pinggy** برای انتشار پورت محلی 8883 تا کلاینت Wokwi بتواند به
بروکر دسترسی داشته باشد.

**۵) بارگذاری کد روی ESP32 (Wokwi):** محتوای `ca.pem` و `esp32_ec.crt` و
`esp32_ec_pkcs8.key` را در متغیرهای مربوطه در `sketch.ino` قرار دهید و آدرس
`MQTT_HOST` و `MQTT_PORT` را روی آدرس Pinggy خود تنظیم کنید. پس از اجرا،
داده‌های حسگر در ThingsBoard دیده می‌شوند و کد Claim روی LCD نمایش داده می‌شود.

**۶) ثبت خودکار (Auto-Provisioning):** در بخش Device provisioning استراتژی را روی
«X.509 Certificates Chain» بگذارید، محتوای `ca.pem` را وارد کنید، عبارت منظم
`(.*)` را تنظیم نمایید و گزینهٔ Allow creating new devices را فعال کنید.

**۷) دراختیارگیری دستگاه (Device Claiming):** دستگاه یک کد محرمانه را روی
`v1/devices/me/claim` منتشر می‌کند و کاربر با رابط وب یا فراخوانی API دستگاه را
دراختیار می‌گیرد (Claim):

</div>

```bash
curl -s -X POST "http://localhost:8080/api/customer/device/esp32-dht-01/claim" \
  -H "X-Authorization: Bearer $CUSTOMER_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"secretKey":"<code-on-lcd>"}'
```

<div dir="rtl">

پاسخ `{"response":"SUCCESS"}` مالکیت دستگاه توسط کاربر نهایی را تأیید می‌کند.

---

## 🛡️ تحلیل امنیتی — mTLS در برابر Access Token ساده

جدول زیر امکان وقوع هر حمله را در دو سامانه مقایسه می‌کند:

</div>

| حمله (Attack) | MQTT + Access Token | سامانهٔ نهایی (mTLS over TLS) |
|---|---|---|
| Eavesdropping | ✅ ممکن — داده و توکن قابل شنود است | ❌ ناممکن — کل ترافیک با TLS رمز می‌شود |
| Credential Theft | ✅ ممکن — توکن یک رشتهٔ ثابت و قابل کپی است | ❌ بسیار سخت — کلید خصوصی روی شبکه ارسال نمی‌شود |
| Device Spoofing | ✅ ممکن — هر کس توکن را داشته باشد جای دستگاه می‌زند | ❌ ناممکن بدون کلید خصوصی دستگاه |
| Man-in-the-Middle | ✅ ممکن — بدون اعتبارسنجی سرور | ❌ مسدود — کلاینت سرور را با CA تأیید می‌کند |
| Replay Attack | ✅ ممکن — بدون اعتبارسنجی | ❌ در لایهٔ TLS مسدود؛ در لایهٔ اپلیکیشن قابل کاهش |

<div dir="rtl">

---

## 🧰 فناوری‌های استفاده‌شده

فناوری‌ها: `ESP32` · `Wokwi` · `Arduino/C++` · `MQTT` · `TLS 1.2 / mTLS` ·
`X.509` · `OpenSSL` · `PKI` · `ThingsBoard` · `Docker` · `Pinggy` · `DHT22` · `LCD I2C`

---

## 📷 تصاویر پروژه

تصاویر پروژه در پوشهٔ `docs/images/` قرار دارند و در ادامه بر اساس مراحل پروژه نمایش داده شده‌اند.

</div>

### ۱) زیرساخت کلید و گواهی‌ها (OpenSSL)
| گواهی ریشه و کلاینت | ساخت گواهی کلاینت ESP32 | تأیید دست‌دهی TLS |
|---|---|---|
| ![ca](docs/images/01-openssl-ca-client.png) | ![client](docs/images/03-esp32-client-cert.png) | ![tls](docs/images/11-tls-handshake.png) |

### ۲) اجرای ThingsBoard روی TLS
| پیکربندی docker-compose | اجرای ThingsBoard | تونل امن Pinggy |
|---|---|---|
| ![compose](docs/images/02-docker-compose.png) | ![tb](docs/images/12-thingsboard-running.png) | ![pinggy](docs/images/13-pinggy-tunnel.png) |

### ۳) دستگاه ESP32 در Wokwi
| مدار دستگاه | اجرای شبیه‌سازی (mTLS) | داده‌های تله‌متری |
|---|---|---|
| ![circuit](docs/images/04-wokwi-circuit.png) | ![sim](docs/images/05-wokwi-simulation.png) | ![telemetry](docs/images/08-tb-telemetry.png) |

### ۴) پروفایل دستگاه و ثبت خودکار
| پروفایل دستگاه | استراتژی X.509 | دستگاه ثبت‌شدهٔ خودکار |
|---|---|---|
| ![profile](docs/images/06-tb-device-profile.png) | ![prov](docs/images/07-tb-provisioning.png) | ![auto](docs/images/15-auto-provisioned-device.png) |

### ۵) تله‌متری، دراختیارگیری و فهرست دستگاه‌ها
| تله‌متری دستگاه خودکار | دراختیارگیری توسط مشتری | تأیید مالکیت (SUCCESS) |
|---|---|---|
| ![autotel](docs/images/16-auto-provision-telemetry.png) | ![customer](docs/images/14-customer-claiming.png) | ![claim](docs/images/09-tb-claim.png) |

| فهرست دستگاه‌ها و گواهی X.509 |
|---|
| ![devices](docs/images/10-tb-devices.png) |

<div dir="rtl">

---

## 👤 توسعه‌دهنده

محسن نوروزی (Mohsen Norouzi)

- گیت‌هاب: [@mohsen-norouzi237](https://github.com/mohsen-norouzi237)
- ایمیل: [mnorouzi2018@gmail.com](mailto:mnorouzi2018@gmail.com)
- لینکدین: [mohsen-norouzi](https://www.linkedin.com/in/mohsen-norouzi-143bb5336/)

---

## 📝 مجوز

این پروژه تحت مجوز [MIT](./LICENSE) منتشر شده است.

</div>
