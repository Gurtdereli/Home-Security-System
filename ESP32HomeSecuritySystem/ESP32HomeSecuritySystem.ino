#include <WiFi.h>
#include <WebServer.h>
#include <ArduinoJson.h>
#include <EEPROM.h>
#include <LiquidCrystal_I2C.h>
#include <Wire.h>

// WiFi Bilgileri
const char* ssid = "";           // WiFi ağ adını buraya yazın
const char* password = "";   // WiFi şifresini buraya yazın

// I2C LCD Pin Tanımlamaları
#define LCD_SDA 21  // I2C SDA pin (GPIO 21)
#define LCD_SCL 22  // I2C SCL pin (GPIO 22)
#define LCD_ADDRESS 0x27  // LCD I2C adresi (genellikle 0x27 veya 0x3F)

// LED ve Buzzer Pin Tanımlamaları
#define LED_GREEN 26        // Yeşil LED (Kapı açık)
#define LED_RED 27          // Kırmızı LED (Kapı kapalı)
#define BUZZER_PIN 14       // Buzzer
#define DOOR_RELAY_PIN 25   // Kapı kilidi röle pin

// HC-SR04 Sensör Pin Tanımlamaları
#define TRIG_PIN 32         // HC-SR04 Trigger pin
#define ECHO_PIN 33         // HC-SR04 Echo pin

// Web Server ve LCD nesneleri
WebServer server(80);
LiquidCrystal_I2C lcd(LCD_ADDRESS, 16, 2);

// Sistem Değişkenleri
String currentPIN = "1234";       // Varsayılan PIN
bool isDoorOpen = false;
unsigned long doorOpenTime = 0;
unsigned long lcdMessageTime = 0;
const unsigned long DOOR_OPEN_DURATION = 3000; // 3 saniye
const unsigned long LCD_MESSAGE_DURATION = 5000; // 5 saniye

// HC-SR04 Sensör Değişkenleri
const float ENTRANCE_THRESHOLD = 50.0; // 50 cm - birisi geçti kabul edilen mesafe
float lastDistance = 0;
unsigned long lastSensorRead = 0;
const unsigned long SENSOR_READ_INTERVAL = 100; // 100ms aralıklarla oku
bool motionDetected = false;
unsigned long motionDetectedTime = 0;
const unsigned long MOTION_TIMEOUT = 5000; // 5 saniye içinde doğrulama yapılmazsa alarm
bool isAuthorized = false;
unsigned long lastAuthTime = 0;
const unsigned long AUTH_TIMEOUT = 10000; // 10 saniye içinde geçiş yapılmazsa sıfırla

// EEPROM Adresleri
#define EEPROM_SIZE 1024
#define PIN_ADDRESS 0
#define CARD_COUNT_ADDRESS 10
#define CARDS_START_ADDRESS 20

// Maksimum kart sayısı ve bilgiler
#define MAX_CARDS 20
#define CARD_ID_LENGTH 16
#define CARD_NAME_LENGTH 32

// Kart yapısı
struct CardInfo {
  String cardId;
  String cardName;
  String ownerName;
};

// Kayıtlı kartlar
CardInfo registeredCards[MAX_CARDS];
int cardCount = 0;
bool isLcdMessageActive = false;

// HC-SR04 mesafe ölçümü fonksiyonu
float measureDistance() {
  digitalWrite(TRIG_PIN, LOW);
  delayMicroseconds(2);
  digitalWrite(TRIG_PIN, HIGH);
  delayMicroseconds(10);
  digitalWrite(TRIG_PIN, LOW);
  
  long duration = pulseIn(ECHO_PIN, HIGH, 30000); // 30ms timeout
  if (duration == 0) {
    return -1; // Timeout hatası
  }
  
  float distance = (duration * 0.034) / 2; // cm cinsinden mesafe
  return distance;
}

// Motion detection kontrol fonksiyonu
void checkMotionDetection() {
  // Sensörü belirli aralıklarla oku
  if (millis() - lastSensorRead >= SENSOR_READ_INTERVAL) {
    lastSensorRead = millis();
    
    float currentDistance = measureDistance();
    
    if (currentDistance > 0) { // Geçerli okuma
      // Mesafe eşik değerin altına düştüyse ve daha önce uzaktaysa
      if (currentDistance < ENTRANCE_THRESHOLD && lastDistance > ENTRANCE_THRESHOLD) {
        Serial.println("Hareket algılandı! Mesafe: " + String(currentDistance) + " cm");
        motionDetected = true;
        motionDetectedTime = millis();
        
        // Hareket algılandı mesajını göster
        showMotionDetectedMessage();
        
        // Eğer daha önce yetki verilmişse ve zaman aşımı olmamışsa
        if (isAuthorized && (millis() - lastAuthTime < AUTH_TIMEOUT)) {
          Serial.println("Yetkili giriş - Alarm yok");
          isAuthorized = false; // Yetki kullanıldı
          motionDetected = false;
          showWelcomeMessage("Yetkili Kullanici", "Giris Onaylandi");
        }
      }
      
      lastDistance = currentDistance;
    }
  }
  
  // Hareket algılandıktan sonra belirli süre geçtiyse ve yetki verilmemişse
  if (motionDetected && !isAuthorized && 
      (millis() - motionDetectedTime > MOTION_TIMEOUT)) {
    
    Serial.println("UYARI: Yetkisiz giriş denemesi!");
    motionDetected = false;
    
    // Yetkisiz giriş alarmı
    triggerUnauthorizedAccessAlarm();
  }
  
  // Yetki timeout kontrolü
  if (isAuthorized && (millis() - lastAuthTime > AUTH_TIMEOUT)) {
    isAuthorized = false;
    Serial.println("Yetki zaman aşımına uğradı");
  }
}

// Yetkisiz giriş alarmı
void triggerUnauthorizedAccessAlarm() {
  Serial.println("ALARM: Yetkisiz giriş algılandı!");
  
  // LCD'de uyarı mesajı göster
  showUnauthorizedAccessMessage();
  
  // Alarm sesi (uzun siren sesi)
  for (int i = 0; i < 10; i++) {
    digitalWrite(BUZZER_PIN, HIGH);
    delay(100);
    digitalWrite(BUZZER_PIN, LOW);
    delay(100);
  }
  
  // Web uygulamasına bildirim gönder (webhook benzeri)
  sendUnauthorizedAccessNotification();
}

// Web uygulamasına bildirim gönderme
void sendUnauthorizedAccessNotification() {
  // Bu fonksiyon web uygulamasının sürekli kontrol etmesi için kullanılacak
  // Alarm durumunu kaydet
  Serial.println("Yetkisiz giriş bildirimi hazırlandı");
}

// Hareket algılandı mesajı
void showMotionDetectedMessage() {
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("HAREKET ALGILANDI");
  lcd.setCursor(0, 1);
  lcd.print("Kimlik Dogrula!");
  
  isLcdMessageActive = true;
  lcdMessageTime = millis();
}

// Yetkisiz giriş mesajı
void showUnauthorizedAccessMessage() {
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("ALARM!");
  lcd.setCursor(0, 1);
  lcd.print("Yetkisiz Giris");
  
  isLcdMessageActive = true;
  lcdMessageTime = millis();
}

// Yanıt fonksiyonları
void sendSuccessResponse(String message, String accessType, String cardId = "") {
  DynamicJsonDocument doc(300);
  doc["success"] = true;
  doc["message"] = message;
  doc["access_type"] = accessType;
  doc["timestamp"] = getTimestamp();
  if (cardId != "") {
    doc["card_id"] = cardId;
  }
  
  String response;
  serializeJson(doc, response);
  
  addCORSHeaders();
  server.send(200, "application/json", response);
  
  Serial.println("Başarılı yanıt: " + message);
  
  // Yetki verildi
  isAuthorized = true;
  lastAuthTime = millis();
  motionDetected = false; // Hareket algılamasını sıfırla
}

void sendErrorResponse(String message, String cardId = "") {
  DynamicJsonDocument doc(300);
  doc["success"] = false;
  doc["message"] = message;
  doc["timestamp"] = getTimestamp();
  if (cardId != "") {
    doc["card_id"] = cardId;
  }
  
  String response;
  serializeJson(doc, response);
  
  addCORSHeaders();
  server.send(400, "application/json", response);
  
  Serial.println("Hata yanıtı: " + message);
}

String getTimestamp() {
  // Basit timestamp (millis bazlı)
  return String(millis());
}

// Debug için yardımcı fonksiyonlar
void printRequestInfo() {
  String method = "";
  switch (server.method()) {
    case HTTP_GET: method = "GET"; break;
    case HTTP_POST: method = "POST"; break;
    case HTTP_OPTIONS: method = "OPTIONS"; break;
    default: method = "UNKNOWN"; break;
  }
  
  Serial.println("\n=== Yeni İstek ===");
  Serial.print("Method: ");
  Serial.println(method);
  Serial.print("URI: ");
  Serial.println(server.uri());
  Serial.print("Headers: ");
  Serial.println(server.headers());
  Serial.print("Args: ");
  Serial.println(server.args());
  
  for (int i = 0; i < server.headers(); i++) {
    Serial.printf("Header[%s]: %s\n", 
      server.headerName(i).c_str(), 
      server.header(i).c_str());
  }
  
  if (server.hasArg("plain")) {
    Serial.print("Body: ");
    Serial.println(server.arg("plain"));
  }
}

void setupWebServer() {
  // CORS için gerekli başlıkları ekleyen yardımcı fonksiyon
  server.enableCORS(true);

  // Ana durum endpoint'i
  server.on("/status", HTTP_GET, []() {
    printRequestInfo();
    addCORSHeaders();
    
    DynamicJsonDocument doc(400);
    doc["status"] = "online";
    doc["door_open"] = isDoorOpen;
    doc["registered_cards"] = cardCount;
    doc["wifi_strength"] = WiFi.RSSI();
    doc["free_heap"] = ESP.getFreeHeap();
    doc["wifi_ssid"] = WiFi.SSID();
    doc["local_ip"] = WiFi.localIP().toString();
    doc["mac_address"] = WiFi.macAddress();
    doc["motion_detected"] = motionDetected;
    doc["unauthorized_access"] = false; // Bu dinamik olarak kontrol edilecek
    doc["last_distance"] = lastDistance;
    
    String response;
    serializeJson(doc, response);
    server.send(200, "application/json", response);
    Serial.println("Status endpoint yanıt gönderildi");
  });
  
  // PIN doğrulama endpoint'i
  server.on("/verify-pin", HTTP_POST, []() {
    addCORSHeaders();
    
    if (!server.hasArg("plain")) {
      sendErrorResponse("JSON verisi bulunamadı");
      return;
    }
    
    String postBody = server.arg("plain");
    DynamicJsonDocument doc(200);
    DeserializationError error = deserializeJson(doc, postBody);
    
    if (error) {
      sendErrorResponse("Geçersiz JSON verisi");
      return;
    }
    
    if (!doc.containsKey("pin")) {
      sendErrorResponse("PIN bulunamadı");
      return;
    }
    
    String pin = doc["pin"].as<String>();
    
    if (pin == currentPIN) {
      sendSuccessResponse("PIN doğru, kapı açılıyor", "pin");
      openDoor("PIN Kullanicisi", "PIN Girisi");
    } else {
      sendErrorResponse("Yanlış PIN");
      showErrorMessage("Yanlis PIN");
      playErrorSound();
    }
  });
  
  // RFID kart doğrulama endpoint'i (NFC için)
  server.on("/verify-rfid", HTTP_POST, []() {
    addCORSHeaders();
    
    if (!server.hasArg("plain")) {
      sendErrorResponse("JSON verisi bulunamadı");
      return;
    }
    
    String postBody = server.arg("plain");
    DynamicJsonDocument doc(200);
    DeserializationError error = deserializeJson(doc, postBody);
    
    if (error) {
      sendErrorResponse("Geçersiz JSON verisi");
      return;
    }
    
    if (!doc.containsKey("card_id")) {
      sendErrorResponse("Kart ID bulunamadı");
      return;
    }
    
    String cardId = doc["card_id"].as<String>();
    
    int cardIndex = findCardIndex(cardId);
    if (cardIndex >= 0) {
      sendSuccessResponse("Kart doğrulandı, kapı açılıyor", "nfc", cardId);
      openDoor(registeredCards[cardIndex].ownerName, registeredCards[cardIndex].cardName);
    } else {
      sendErrorResponse("Bilinmeyen kart", cardId);
      showErrorMessage("Bilinmeyen Kart");
      playErrorSound();
    }
  });
  
  // Yeni kart ekleme endpoint'i (NFC için)
  server.on("/add-rfid", HTTP_POST, []() {
    addCORSHeaders();
    
    if (!server.hasArg("plain")) {
      sendErrorResponse("JSON verisi bulunamadı");
      return;
    }
    
    String postBody = server.arg("plain");
    DynamicJsonDocument doc(500);
    DeserializationError error = deserializeJson(doc, postBody);
    
    if (error) {
      sendErrorResponse("Geçersiz JSON verisi");
      return;
    }
    
    if (!doc.containsKey("card_id") || !doc.containsKey("card_name") || !doc.containsKey("owner_name")) {
      sendErrorResponse("Eksik veri");
      return;
    }
    
    String cardId = doc["card_id"].as<String>();
    String cardName = doc["card_name"].as<String>();
    String ownerName = doc["owner_name"].as<String>();
    
    if (cardCount >= MAX_CARDS) {
      sendErrorResponse("Maksimum kart sayısına ulaşıldı");
      return;
    }
    
    if (findCardIndex(cardId) >= 0) {
      sendErrorResponse("Kart zaten kayıtlı");
      return;
    }
    
    // Yeni kart ekle
    registeredCards[cardCount].cardId = cardId;
    registeredCards[cardCount].cardName = cardName.length() > 0 ? cardName : "Kart " + String(cardCount+1);
    registeredCards[cardCount].ownerName = ownerName.length() > 0 ? ownerName : registeredCards[cardCount].cardName;
    cardCount++;
    saveCards();
    
    showCardAddedMessage(registeredCards[cardCount-1].ownerName, registeredCards[cardCount-1].cardName);
    
    sendSuccessResponse("Kart başarıyla eklendi: " + cardName, "card_added", cardId);
    playSuccessSound();
  });

  // Kart silme endpoint'i - YENİ!
  server.on("/delete-rfid", HTTP_POST, []() {
    addCORSHeaders();
    
    if (!server.hasArg("plain")) {
      sendErrorResponse("JSON verisi bulunamadı");
      return;
    }
    
    String postBody = server.arg("plain");
    DynamicJsonDocument doc(200);
    DeserializationError error = deserializeJson(doc, postBody);
    
    if (error) {
      sendErrorResponse("Geçersiz JSON verisi");
      return;
    }
    
    if (!doc.containsKey("card_id")) {
      sendErrorResponse("Kart ID bulunamadı");
      return;
    }
    
    String cardId = doc["card_id"].as<String>();
    int cardIndex = findCardIndex(cardId);
    
    if (cardIndex < 0) {
      sendErrorResponse("Kart bulunamadı");
      return;
    }
    
    String deletedCardName = registeredCards[cardIndex].cardName;
    
    // Kartı diziden çıkar
    for (int i = cardIndex; i < cardCount - 1; i++) {
      registeredCards[i] = registeredCards[i + 1];
    }
    cardCount--;
    
    // Değişiklikleri kaydet
    saveCards();
    
    showCardDeletedMessage(deletedCardName);
    
    sendSuccessResponse("Kart başarıyla silindi: " + deletedCardName, "card_deleted", cardId);
    playSuccessSound();
  });
  
  // Kart listesi endpoint'i
  server.on("/list-cards", HTTP_GET, []() {
    addCORSHeaders();
    
    DynamicJsonDocument doc(1000);
    doc["success"] = true;
    doc["card_count"] = cardCount;
    
    JsonArray cards = doc.createNestedArray("cards");
    for (int i = 0; i < cardCount; i++) {
      JsonObject card = cards.createNestedObject();
      card["id"] = registeredCards[i].cardId;
      card["name"] = registeredCards[i].cardName;
      card["owner"] = registeredCards[i].ownerName;
    }
    
    String response;
    serializeJson(doc, response);
    server.send(200, "application/json", response);
  });
  
  // PIN değiştirme endpoint'i
  server.on("/change-pin", HTTP_POST, []() {
    addCORSHeaders();
    
    if (!server.hasArg("plain")) {
      sendErrorResponse("JSON verisi bulunamadı");
      return;
    }
    
    String postBody = server.arg("plain");
    DynamicJsonDocument doc(300);
    DeserializationError error = deserializeJson(doc, postBody);
    
    if (error) {
      sendErrorResponse("Geçersiz JSON verisi");
      return;
    }
    
    if (!doc.containsKey("old_pin") || !doc.containsKey("new_pin")) {
      sendErrorResponse("Eksik veri");
      return;
    }
    
    String oldPin = doc["old_pin"].as<String>();
    String newPin = doc["new_pin"].as<String>();
    
    if (oldPin != currentPIN) {
      sendErrorResponse("Mevcut PIN yanlış");
      showErrorMessage("Eski PIN Yanlis");
      playErrorSound();
      return;
    }
    
    if (newPin.length() != 4) {
      sendErrorResponse("PIN 4 haneli olmalıdır");
      return;
    }
    
    currentPIN = newPin;
    savePIN();
    
    showPinChangedMessage();
    
    sendSuccessResponse("PIN başarıyla değiştirildi", "pin_changed");
    playSuccessSound();
  });
  
  // Kapı açma endpoint'i
  server.on("/open-door", HTTP_POST, []() {
    addCORSHeaders();
    sendSuccessResponse("Kapı manuel olarak açıldı", "manual");
    openDoor("Uzaktan Erisim", "Manuel Komut");
  });

  // OPTIONS isteklerini işle
  server.on("/status", HTTP_OPTIONS, handleOptions);
  server.on("/verify-pin", HTTP_OPTIONS, handleOptions);
  server.on("/verify-rfid", HTTP_OPTIONS, handleOptions);
  server.on("/add-rfid", HTTP_OPTIONS, handleOptions);
  server.on("/delete-rfid", HTTP_OPTIONS, handleOptions);
  server.on("/list-cards", HTTP_OPTIONS, handleOptions);
  server.on("/change-pin", HTTP_OPTIONS, handleOptions);
  server.on("/open-door", HTTP_OPTIONS, handleOptions);
}

// CORS başlıklarını ekleyen yardımcı fonksiyon
void addCORSHeaders() {
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.sendHeader("Access-Control-Allow-Methods", "GET,POST,OPTIONS");
  server.sendHeader("Access-Control-Allow-Headers", "Content-Type");
}

// OPTIONS isteklerini işleyen fonksiyon
void handleOptions() {
  addCORSHeaders();
  server.send(200);
}

void checkDoorStatus() {
  // Kapı açık kalma süresi kontrolü
  if (isDoorOpen && millis() - doorOpenTime > DOOR_OPEN_DURATION) {
    closeDoor();
  }
}

void openDoor(String ownerName, String cardName) {
  if (!isDoorOpen) {
    Serial.println("Kapı açılıyor - " + ownerName);
    
    // Röleyi aktif et (kapıyı aç)
    digitalWrite(DOOR_RELAY_PIN, HIGH);
    
    // LED'leri güncelle
    digitalWrite(LED_RED, LOW);
    digitalWrite(LED_GREEN, HIGH);
    
    // Hoş geldiniz mesajını göster
    showWelcomeMessage(ownerName, cardName);
    
    isDoorOpen = true;
    doorOpenTime = millis();
    
    // Kapı açılma sesi
    digitalWrite(BUZZER_PIN, HIGH);
    delay(200);
    digitalWrite(BUZZER_PIN, LOW);
  }
}

void closeDoor() {
  if (isDoorOpen) {
    Serial.println("Kapı kapanıyor...");
    
    // Röleyi deaktif et (kapıyı kapat)
    digitalWrite(DOOR_RELAY_PIN, LOW);
    
    // LED'leri güncelle
    digitalWrite(LED_RED, HIGH);
    digitalWrite(LED_GREEN, LOW);
    
    isDoorOpen = false;
    
    // Ana ekranı göster
    showMainScreen();
    
    // Kapı kapanma sesi
    digitalWrite(BUZZER_PIN, HIGH);
    delay(100);
    digitalWrite(BUZZER_PIN, LOW);
  }
}

int findCardIndex(String cardId) {
  for (int i = 0; i < cardCount; i++) {
    if (registeredCards[i].cardId == cardId) {
      return i;
    }
  }
  return -1;
}

void playStartupSound() {
  // Başlangıç sesi (yükselen ton)
  for (int i = 0; i < 3; i++) {
    digitalWrite(BUZZER_PIN, HIGH);
    delay(100);
    digitalWrite(BUZZER_PIN, LOW);
    delay(50);
  }
}

void playSuccessSound() {
  // Başarı sesi (çift bip)
  digitalWrite(BUZZER_PIN, HIGH);
  delay(200);
  digitalWrite(BUZZER_PIN, LOW);
  delay(100);
  digitalWrite(BUZZER_PIN, HIGH);
  delay(200);
  digitalWrite(BUZZER_PIN, LOW);
}

void playErrorSound() {
  // Hata sesi (uzun tek bip)
  digitalWrite(BUZZER_PIN, HIGH);
  delay(500);
  digitalWrite(BUZZER_PIN, LOW);
}

void resetSettings() {
  Serial.println("Ayarlar sıfırlanıyor...");
  
  // PIN'i varsayılan değere sıfırla
  for (int i = 0; i < 4; i++) {
    EEPROM.write(PIN_ADDRESS + i, currentPIN.charAt(i));
  }
  
  // Kart sayısını sıfırla
  EEPROM.write(CARD_COUNT_ADDRESS, 0);
  cardCount = 0;
  
  // EEPROM'u kaydet
  EEPROM.commit();
  
  Serial.println("Ayarlar sıfırlandı!");
  Serial.println("Varsayılan PIN: " + currentPIN);
}

void loadSettings() {
  Serial.println("\nAyarlar yükleniyor...");
  
  // PIN'i yükle
  String loadedPIN = "";
  bool isPINValid = true;
  
  for (int i = 0; i < 4; i++) {
    char c = char(EEPROM.read(PIN_ADDRESS + i));
    if (c >= '0' && c <= '9') {
      loadedPIN += c;
    } else {
      isPINValid = false;
      break;
    }
  }
  
  if (isPINValid && loadedPIN.length() == 4) {
    currentPIN = loadedPIN;
    Serial.println("PIN EEPROM'dan yüklendi: " + currentPIN);
  } else {
    Serial.println("Geçersiz PIN! Varsayılan PIN kullanılıyor...");
    resetSettings(); // Ayarları sıfırla
  }
  
  // Kart sayısını yükle
  cardCount = EEPROM.read(CARD_COUNT_ADDRESS);
  if (cardCount > MAX_CARDS || cardCount < 0) {
    Serial.println("Geçersiz kart sayısı! Sıfırlanıyor...");
    cardCount = 0;
    EEPROM.write(CARD_COUNT_ADDRESS, 0);
    EEPROM.commit();
  }
  
  // Kartları yükle
  for (int i = 0; i < cardCount; i++) {
    int baseAddress = CARDS_START_ADDRESS + (i * (CARD_ID_LENGTH + CARD_NAME_LENGTH * 2));
    
    // Kart ID'sini oku
    String cardId = "";
    bool isCardValid = true;
    
    for (int j = 0; j < CARD_ID_LENGTH; j++) {
      char c = char(EEPROM.read(baseAddress + j));
      if ((c >= '0' && c <= '9') || (c >= 'A' && c <= 'F')) {
        cardId += c;
      } else if (c != '\0') {
        isCardValid = false;
        break;
      }
    }
    
    if (!isCardValid) {
      Serial.println("Kart #" + String(i+1) + " geçersiz! Atlanıyor...");
      continue;
    }
    
    // Kart adını oku
    String cardName = "";
    for (int j = 0; j < CARD_NAME_LENGTH; j++) {
      char c = char(EEPROM.read(baseAddress + CARD_ID_LENGTH + j));
      if (c == '\0') break;
      cardName += c;
    }
    
    // Sahip adını oku
    String ownerName = "";
    for (int j = 0; j < CARD_NAME_LENGTH; j++) {
      char c = char(EEPROM.read(baseAddress + CARD_ID_LENGTH + CARD_NAME_LENGTH + j));
      if (c == '\0') break;
      ownerName += c;
    }
    
    if (cardId.length() > 0) {
      registeredCards[i].cardId = cardId;
      registeredCards[i].cardName = cardName.length() > 0 ? cardName : "Kart " + String(i+1);
      registeredCards[i].ownerName = ownerName.length() > 0 ? ownerName : registeredCards[i].cardName;
      Serial.println("Kart #" + String(i+1) + " yüklendi: " + cardId);
    }
  }
  
  Serial.println("Ayarlar yüklendi:");
  Serial.println("- PIN: " + currentPIN);
  Serial.println("- Kayıtlı kart sayısı: " + String(cardCount));
}

void savePIN() {
  for (int i = 0; i < 4; i++) {
    EEPROM.write(PIN_ADDRESS + i, currentPIN.charAt(i));
  }
  EEPROM.commit();
  Serial.println("PIN kaydedildi");
}

void saveCards() {
  // Kart sayısını kaydet
  EEPROM.write(CARD_COUNT_ADDRESS, cardCount);
  
  // Kartları kaydet
  for (int i = 0; i < cardCount; i++) {
    int baseAddress = CARDS_START_ADDRESS + (i * (CARD_ID_LENGTH + CARD_NAME_LENGTH * 2));
    
    // Kart ID'sini kaydet
    String cardId = registeredCards[i].cardId;
    for (int j = 0; j < CARD_ID_LENGTH; j++) {
      char c = (j < cardId.length()) ? cardId.charAt(j) : '\0';
      EEPROM.write(baseAddress + j, c);
    }
    
    // Kart adını kaydet
    String cardName = registeredCards[i].cardName;
    for (int j = 0; j < CARD_NAME_LENGTH; j++) {
      char c = (j < cardName.length()) ? cardName.charAt(j) : '\0';
      EEPROM.write(baseAddress + CARD_ID_LENGTH + j, c);
    }
    
    // Sahip adını kaydet
    String ownerName = registeredCards[i].ownerName;
    for (int j = 0; j < CARD_NAME_LENGTH; j++) {
      char c = (j < ownerName.length()) ? ownerName.charAt(j) : '\0';
      EEPROM.write(baseAddress + CARD_ID_LENGTH + CARD_NAME_LENGTH + j, c);
    }
  }
  
  EEPROM.commit();
  Serial.println("Kartlar kaydedildi");
}

void connectToWiFi() {
  Serial.println("\n=== WiFi Bağlantısı Başlatılıyor ===");
  Serial.print("Bağlanılacak ağ: ");
  Serial.println(ssid);
  
  // WiFi modunu ayarla
  WiFi.mode(WIFI_STA);
  WiFi.disconnect();
  delay(100);
  
  // Statik IP ayarla
  IPAddress localIP(192, 168, 1, 9);
  IPAddress gateway(192, 168, 1, 1);
  IPAddress subnet(255, 255, 255, 0);
  IPAddress dns1(8, 8, 8, 8);
  IPAddress dns2(8, 8, 4, 4);
  
  if (!WiFi.config(localIP, gateway, subnet, dns1, dns2)) {
    Serial.println("Statik IP yapılandırması başarısız!");
  }
  
  // Bağlantıyı başlat
  WiFi.begin(ssid, password);
  
  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 20) {
    delay(500);
    Serial.print(".");
    attempts++;
  }
  
  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\n=== WiFi Bağlantısı Başarılı ===");
    Serial.print("IP Adresi: ");
    Serial.println(WiFi.localIP());
    Serial.print("Ağ geçidi: ");
    Serial.println(WiFi.gatewayIP());
    Serial.print("Alt ağ maskesi: ");
    Serial.println(WiFi.subnetMask());
    Serial.print("DNS 1: ");
    Serial.println(WiFi.dnsIP(0));
    Serial.print("DNS 2: ");
    Serial.println(WiFi.dnsIP(1));
    Serial.print("MAC Adresi: ");
    Serial.println(WiFi.macAddress());
    Serial.print("Sinyal Gücü (RSSI): ");
    Serial.print(WiFi.RSSI());
    Serial.println(" dBm");
    
    // Bağlantı başarılı sesi
    digitalWrite(BUZZER_PIN, HIGH);
    delay(100);
    digitalWrite(BUZZER_PIN, LOW);
    delay(100);
    digitalWrite(BUZZER_PIN, HIGH);
    delay(100);
    digitalWrite(BUZZER_PIN, LOW);
  } else {
    Serial.println("\n=== WiFi Bağlantısı Başarısız ===");
    Serial.println("Yeniden başlatılıyor...");
    
    // Hata sesi
    for (int i = 0; i < 5; i++) {
      digitalWrite(BUZZER_PIN, HIGH);
      delay(200);
      digitalWrite(BUZZER_PIN, LOW);
      delay(200);
    }
    
    // ESP32'yi yeniden başlat
    ESP.restart();
  }
}

void checkWiFiConnection() {
  static unsigned long lastCheck = 0;
  static bool wasConnected = false;
  static int reconnectAttempts = 0;
  
  // Her 30 saniyede bir kontrol et
  if (millis() - lastCheck >= 30000) {
    lastCheck = millis();
    
    if (WiFi.status() != WL_CONNECTED) {
      Serial.println("\n=== WiFi Durum Kontrolü ===");
      Serial.println("Bağlantı durumu: Bağlı değil");
      Serial.print("SSID: ");
      Serial.println(WiFi.SSID());
      Serial.print("Sinyal gücü: ");
      Serial.print(WiFi.RSSI());
      Serial.println(" dBm");
      
      if (wasConnected) {
        Serial.println("WiFi bağlantısı koptu!");
        reconnectAttempts++;
        
        if (reconnectAttempts > 3) {
          Serial.println("Çok fazla yeniden bağlanma denemesi, sistem yeniden başlatılıyor...");
          ESP.restart();
        }
        
        wasConnected = false;
        connectToWiFi();
      }
    } else {
      if (!wasConnected) {
        Serial.println("\n=== WiFi Bağlantısı Geri Geldi ===");
        Serial.print("IP Adresi: ");
        Serial.println(WiFi.localIP());
        Serial.print("Ağ geçidi: ");
        Serial.println(WiFi.gatewayIP());
        Serial.print("DNS: ");
        Serial.println(WiFi.dnsIP());
        wasConnected = true;
        reconnectAttempts = 0;
      }
    }
  }
}

void showMainScreen() {
  if (!isLcdMessageActive) {
    lcd.clear();
    lcd.setCursor(0, 0);
    lcd.print("Hos Geldiniz");
    lcd.setCursor(0, 1);
    lcd.print("Lutfen giris yapin");
  }
}

void showWelcomeMessage(String ownerName, String cardName) {
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("Hos Geldiniz!");
  
  // İsmi kısalt (16 karakter max)
  String displayName = ownerName;
  if (displayName.length() > 16) {
    displayName = displayName.substring(0, 16);
  }
  
  lcd.setCursor(0, 1);
  lcd.print(displayName);
  
  isLcdMessageActive = true;
  lcdMessageTime = millis();
}

void showErrorMessage(String message) {
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("ERISIM REDDEDILDI");
  lcd.setCursor(0, 1);
  lcd.print(message);
  
  isLcdMessageActive = true;
  lcdMessageTime = millis();
}

void showCardAddedMessage(String ownerName, String cardName) {
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("Yeni Kart Eklendi");
  lcd.setCursor(0, 1);
  
  String displayName = ownerName;
  if (displayName.length() > 16) {
    displayName = displayName.substring(0, 16);
  }
  lcd.print(displayName);
  
  isLcdMessageActive = true;
  lcdMessageTime = millis();
}

void showPinChangedMessage() {
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("PIN Degistirildi");
  lcd.setCursor(0, 1);
  lcd.print("Yeni PIN: ****");
  
  isLcdMessageActive = true;
  lcdMessageTime = millis();
}

void showCardDeletedMessage(String cardName) {
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("Kart Silindi");
  lcd.setCursor(0, 1);
  
  String displayName = cardName;
  if (displayName.length() > 16) {
    displayName = displayName.substring(0, 16);
  }
  lcd.print(displayName);
  
  isLcdMessageActive = true;
  lcdMessageTime = millis();
}

void checkLcdMessage() {
  if (isLcdMessageActive && millis() - lcdMessageTime > LCD_MESSAGE_DURATION) {
    isLcdMessageActive = false;
    showMainScreen();
  }
}

void setup() {
  Serial.begin(115200);
  Serial.println("\n=== Ev Güvenlik Sistemi Başlatılıyor ===");
  
  // I2C ve LCD başlat
  Wire.begin(LCD_SDA, LCD_SCL);
  lcd.init();
  lcd.backlight();
  
  // LCD başlangıç mesajı
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("Ev Guvenlik");
  lcd.setCursor(0, 1);
  lcd.print("Sistemi");
  delay(2000);
  
  // Pin modlarını ayarla
  pinMode(LED_GREEN, OUTPUT);
  pinMode(LED_RED, OUTPUT);
  pinMode(BUZZER_PIN, OUTPUT);
  pinMode(DOOR_RELAY_PIN, OUTPUT);
  pinMode(TRIG_PIN, OUTPUT);
  pinMode(ECHO_PIN, INPUT);
  
  // Başlangıç durumu
  digitalWrite(LED_RED, HIGH);
  digitalWrite(LED_GREEN, LOW);
  digitalWrite(DOOR_RELAY_PIN, LOW); // Kapı kapalı
  digitalWrite(TRIG_PIN, LOW);
  
  // EEPROM başlat
  if (!EEPROM.begin(EEPROM_SIZE)) {
    Serial.println("EEPROM başlatılamadı!");
    delay(1000);
    ESP.restart();
  }
  Serial.println("EEPROM başlatıldı");
  
  // EEPROM'dan ayarları yükle
  loadSettings();
  
  // WiFi bağlantısını başlat
  connectToWiFi();
  
  // Web server endpoint'lerini tanımla
  setupWebServer();
  
  // Web server'ı başlat
  server.begin();
  Serial.println("HTTP server başlatıldı");
  Serial.print("IP Adresi: ");
  Serial.println(WiFi.localIP());
  
  // HC-SR04 sensör testi
  Serial.println("HC-SR04 sensörü test ediliyor...");
  float testDistance = measureDistance();
  if (testDistance > 0) {
    Serial.println("HC-SR04 çalışıyor. İlk mesafe: " + String(testDistance) + " cm");
    lastDistance = testDistance;
  } else {
    Serial.println("HC-SR04 sensör hatası!");
  }
  
  // LCD'ye IP adresini göster
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("IP:");
  lcd.setCursor(3, 0);
  lcd.print(WiFi.localIP());
  lcd.setCursor(0, 1);
  lcd.print("Sistem Hazir");
  delay(3000);
  
  // Başlangıç sesleri
  playStartupSound();
  
  // Ana ekranı göster
  showMainScreen();
  
  Serial.println("Ev Güvenlik Sistemi hazır!");
  Serial.println("Giriş sensörü aktif...");
}

void loop() {
  // WiFi bağlantısını kontrol et
  checkWiFiConnection();
  
  // Web server isteklerini işle
  server.handleClient();
  
  // Kapı durumunu kontrol et
  checkDoorStatus();
  
  // Hareket algılama kontrolü - YENİ!
  checkMotionDetection();
  
  // LCD mesaj süresini kontrol et
  checkLcdMessage();
  
  // Küçük gecikme
  delay(10);
} 