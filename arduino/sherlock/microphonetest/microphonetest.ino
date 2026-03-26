int soundSensor1 = A0;
int soundSensor2 = A1;
int soundSensor3 = A2;

void setup() {
  Serial.begin(230400);
}

void loop() {
  int SensorData1 = analogRead(soundSensor1);
  int SensorData2 = analogRead(soundSensor2);
  int SensorData3 = analogRead(soundSensor3);
  Serial.print(SensorData1);
  Serial.print(",");
  Serial.print(SensorData2);
  Serial.print(",");
  Serial.println(SensorData3);
}