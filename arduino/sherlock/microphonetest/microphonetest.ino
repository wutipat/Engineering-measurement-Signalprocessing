int soundSensor1 = A0;
int soundSensor2 = A1;
int soundSensor3 = A2;
int soundSensor4 = A3;

void setup() {
  Serial.begin(115200);
}

void loop() {
  int SensorData1 = analogRead(soundSensor1);
  int SensorData2 = analogRead(soundSensor2);
  int SensorData3 = analogRead(soundSensor3);
  int SensorData4 = analogRead(soundSensor4);
  Serial.print(SensorData1);
  Serial.print(",");
  Serial.print(SensorData2);
  Serial.print(",");
  Serial.print(SensorData3);
  Serial.print(",");
  Serial.print(SensorData4);
  Serial.print(",");
  Serial.print(0);
  Serial.print(",");
  Serial.println(1024);
}