/*********************************************************************************************************
*
* File                : DustSensor
* Hardware Environment: 
* Build Environment   : Arduino
* Version             : V1.0.5-r2
* By                  : WaveShare
*
*                                  (c) Copyright 2005-2011, WaveShare
*                                       http://www.waveshare.net
*                                       http://www.waveshare.com   
*                                          All Rights Reserved
*
*********************************************************************************************************/
#define COV_RATIO 0.2       //ug/mmm / mv
#define NO_DUST_VOLTAGE 400 //mv
#define SYS_VOLTAGE 5000

#include <Arduino.h>
#include <M5Stack.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include <Adafruit_MLX90614.h>

BLEServer *pServer = NULL;
BLECharacteristic *pCharacteristic = NULL;
bool deviceConnected = false;
bool oldDeviceConnected = false;

#define SERVICE_UUID "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define CHARACTERISTIC_UUID "beb5483e-36e1-4688-b7f5-ea07361b26a8"

//遠赤外線温度センサ関係
Adafruit_MLX90614 mlx = Adafruit_MLX90614();
float Em = 0.98;
float TempEm(float Em, float TA, float TO);

float TempEm(float Em, float TA, float TO)
{
  TA = TA + 273.15;
  TO = TO + 273.15;
  float T = (TO * TO * TO * TO) / Em + (TA * TA * TA * TA) * (1 - (1 / Em));
  float Temp = sqrt(sqrt(T)) - 273.15;
  return Temp;
}

class MyServerCallbacks : public BLEServerCallbacks
{
  void onConnect(BLEServer *pServer)
  {
    deviceConnected = true;
    BLEDevice::startAdvertising();
  };

  void onDisconnect(BLEServer *pServer)
  {
    deviceConnected = false;
  }
};

/*
I/O define
*/
const int iled = 12; //drive the led of sensor
const int vout = 36; //analog input

/*
variable
*/
float density, voltage;
int adcvalue;

/*
private function
*/
int Filter(int m)
{
  static int flag_first = 0, _buff[10], sum;
  const int _buff_max = 10;
  int i;

  if (flag_first == 0)
  {
    flag_first = 1;

    for (i = 0, sum = 0; i < _buff_max; i++)
    {
      _buff[i] = m;
      sum += _buff[i];
    }
    return m;
  }
  else
  {
    sum -= _buff[0];
    for (i = 0; i < (_buff_max - 1); i++)
    {
      _buff[i] = _buff[i + 1];
    }
    _buff[9] = m;
    sum += _buff[9];

    i = sum / 10.0;
    return i;
  }
}

void setup(void)
{
  pinMode(iled, OUTPUT);
  digitalWrite(iled, LOW); //iled default closed

  Serial.begin(115200); //send and receive at 115200 baud
  mlx.begin();
  M5.begin();
  Serial.print("*********************************** WaveShare ***********************************\n");

  // Create the BLE Device
  BLEDevice::init("ESP32 THAT PROJECT");

  // Create the BLE Server
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());

  // Create the BLE Service
  BLEService *pService = pServer->createService(SERVICE_UUID);

  // Create a BLE Characteristic
  pCharacteristic = pService->createCharacteristic(
      CHARACTERISTIC_UUID,
      BLECharacteristic::PROPERTY_READ |
          BLECharacteristic::PROPERTY_WRITE |
          BLECharacteristic::PROPERTY_NOTIFY |
          BLECharacteristic::PROPERTY_INDICATE);

  // https://www.bluetooth.com/specifications/gatt/viewer?attributeXmlFile=org.bluetooth.descriptor.gatt.client_characteristic_configuration.xml
  // Create a BLE Descriptor
  pCharacteristic->addDescriptor(new BLE2902());

  // Start the service
  pService->start();

  // Start advertising
  BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(false);
  pAdvertising->setMinPreferred(0x0); // set value to 0x00 to not advertise this parameter
  BLEDevice::startAdvertising();
  Serial.println("Waiting a client connection to notify...");

  M5.Lcd.setTextColor(WHITE);
  M5.Lcd.setTextFont(3);
  M5.Lcd.setCursor(0, 0);
  M5.Lcd.print("Start BLE");
  delay(1000);
  M5.Lcd.fillScreen(BLACK);
}

void loop(void)
{
  M5.update();
  float temp_obj_c = mlx.readObjectTempC();
  float temp_amb_c = mlx.readAmbientTempC();
  float temp_crr_c = TempEm(Em, temp_amb_c, temp_obj_c);
  Serial.print("The current dust concentration is: ");
  Serial.print(temp_crr_c);
  Serial.print("deg.(C)");

  // notify changed value
  if (deviceConnected)
  {
    String str = "";
    str += temp_crr_c;

    pCharacteristic->setValue((char *)str.c_str());
    pCharacteristic->notify();
  }
  // disconnecting
  if (!deviceConnected && oldDeviceConnected)
  {
    delay(500);                  // give the bluetooth stack the chance to get things ready
    pServer->startAdvertising(); // restart advertising
    Serial.println("start advertising");
    M5.Lcd.setCursor(0, 0);
    M5.Lcd.print("start advertising");
    oldDeviceConnected = deviceConnected;
  }
  // connecting
  if (deviceConnected && !oldDeviceConnected)
  {
    // do stuff here on connecting
    oldDeviceConnected = deviceConnected;
  }

  delay(500);
}