#include <Arduino.h>
#include <WiFi.h>
#include <FirebaseESP32.h>
#include "addons/TokenHelper.h"
#include "addons/RTDBHelper.h"

const char *ssid = "OPPO Reno11Pro";
const char *password = "SarviRock";

#define API_KEY "AIzaSyCaiM94n3q9pYbsASvDXCfoikoUOl6nsew"
#define DATABASE_URL "https://smart-car-parking-9a6dc-default-rtdb.firebaseio.com"

const int ledPin = 2;

const int pins[] = {13, 27, 33, 34};
const int pinCount = sizeof(pins) / sizeof(pins[0]);

FirebaseData firebaseData;
FirebaseAuth auth;
FirebaseConfig config;

void setup()
{
  Serial.begin(115200);

  pinMode(ledPin, OUTPUT);
  digitalWrite(ledPin, LOW);

  for (int i = 0; i < pinCount; i++)
  {
    pinMode(pins[i], INPUT);
  }

  Serial.println("Connecting to WiFi...");
  WiFi.begin(ssid, password);
  while (WiFi.status() != WL_CONNECTED)
  {
    for (int i = 0; i < 5; i++)
    {
      digitalWrite(ledPin, HIGH);
      delay(100);
      digitalWrite(ledPin, LOW);
      delay(100);
    }
    Serial.println("Connecting...");
    if (WiFi.status() == WL_CONNECT_FAILED) {
      Serial.println("Failed to connect to WiFi");
      digitalWrite(ledPin, LOW);
      return;
    }
  }
  Serial.println("Connected to WiFi!");
  digitalWrite(ledPin, HIGH);

  config.api_key = API_KEY;
  config.database_url = DATABASE_URL;

  auth.user.email = "";
  auth.user.password = "";

  if (Firebase.signUp(&config, &auth, "", ""))
  {
    Serial.println("Signed up successfully!");
  }
  else
  {
    Serial.printf("Sign Up Error: %s\n", config.signer.signupError.message.c_str());
  }
  config.token_status_callback = tokenStatusCallback;

  Firebase.begin(&config, &auth);
  Firebase.reconnectWiFi(true);

  Serial.println("Connected to Firebase!");
}

int getIntStatus()
{
  int number = 0;
  for (int i = 0; i < pinCount; ++i)
  {
    number |= digitalRead(pins[i]) << i;
  }
  return number;
}

void loop()
{
  if (Firebase.getInt(firebaseData, "/parkings"))
  {
    if (firebaseData.dataType() == "int")
    {
      int state = firebaseData.intData();
      int currentState = getIntStatus();
      if (state != currentState)
      {
        Firebase.setInt(firebaseData, "/parkings", currentState);
      }
    }
  }
  else
  {
    Serial.println("Failed to get LED state from Firebase!");
    Serial.println(firebaseData.errorReason());
  }
  delay(1000);
}