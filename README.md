# Ev Güvenlik Sistemi

Bu proje, ESP32 mikrodenetleyici ve Flutter mobil uygulama kullanarak geliştirilmiş kapsamlı bir ev güvenlik sistemi çözümüdür.

## Özellikler

### Donanım Bileşenleri
- ESP32 mikrodenetleyici
- HC-SR04 ultrasonik mesafe sensörü
- LCD ekran
- LED'ler
- Buzzer
- Röle
- RFID kart okuyucu

### Ana Özellikler
1. **Hareket Algılama Sistemi**
   - 50cm mesafe eşiğinde hareket algılama
   - 5 saniye içinde kimlik doğrulama gerekliliği
   - LCD ekranda durum bildirimleri

2. **Giriş Kontrol Sistemi**
   - RFID kart ile giriş
   - PIN kodu doğrulama
   - 10 saniye yetki süresi
   - Yetkili/yetkisiz giriş kontrolü

3. **Flutter Mobil Uygulama**
   - Gerçek zamanlı sistem durumu izleme
   - RFID kart yönetimi (ekleme/silme)
   - Anlık bildirim sistemi
   - Sistem ayarları yönetimi

## Kurulum

### Donanım Kurulumu
1. ESP32 bağlantılarını şemaya göre yapın
2. Sensörleri ve diğer bileşenleri bağlayın
3. ESP32 kodunu yükleyin

### Mobil Uygulama Kurulumu
1. Flutter'ı yükleyin
2. Proje bağımlılıklarını yükleyin:
   ```bash
   flutter pub get
   ```
3. Uygulamayı derleyin ve çalıştırın:
   ```bash
   flutter run
   ```

## Proje Yapısı
- `/esp32_code` - ESP32 firmware kodları
- `/lib` - Flutter uygulama kodları
- `/assets` - Uygulama görselleri ve kaynakları

## Gereksinimler
- Flutter SDK
- Arduino IDE
- ESP32 Board Manager
- Gerekli Arduino kütüphaneleri

## Lisans
Bu proje MIT lisansı altında lisanslanmıştır.

## İletişim
Sorularınız ve önerileriniz için lütfen GitHub üzerinden issue açın.
