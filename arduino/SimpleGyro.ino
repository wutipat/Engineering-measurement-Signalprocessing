/*
  Arduino LSM9DS1 - Gyroscope Application

  This example reads the gyroscope values from the LSM9DS1 sensor 
  and prints them to the Serial Monitor or Serial Plotter, as a directional detection of 
  an axis' angular velocity.

  The circuit:
  - Arduino Nano 33 BLE Sense

  Created by Riccardo Rizzo

  Modified by Benjamin Dannegård
  30 Nov 2020

  This example code is in the public domain.
*/

#include <Arduino_LSM9DS1.h>

float x, y, z;
int plusThreshold = 30, minusThreshold = -30;

void setup() {
  Serial.begin(9600);
  while (!Serial);
  Serial.println("Started");

  if (!IMU.begin()) {
    Serial.println("Failed to initialize IMU!");
    while (1);
  }
  Serial.print("Gyroscope sample rate = ");
  Serial.print(IMU.gyroscopeSampleRate());
  Serial.println(" Hz");
  Serial.println();
  Serial.println("Gyroscope in degrees/second");
  Serial.println("X: Y: Z:");
  //Serial.println("Angular velocity in X Y Z: ");
}
void loop() {
  
  if (IMU.gyroscopeAvailable()) {
    IMU.readGyroscope(x, y, z);
  }

  Serial.print("gX:");
  Serial.print(x);
  Serial.print(" \t");
  Serial.print("gY:");
  Serial.print(y);
  Serial.print(" \t");
  Serial.print("gZ:");
  Serial.print(z);
  Serial.println("");
  delay(50);

  
}
