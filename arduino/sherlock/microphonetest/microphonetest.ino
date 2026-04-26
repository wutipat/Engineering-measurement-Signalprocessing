// Wires: Pin A -> D2, Pin B -> D3
const int pinA = 2; 
const int pinB = 3;

volatile long pulseCount = 0; 

void setup() {
  pinMode(pinA, INPUT_PULLUP);
  pinMode(pinB, INPUT_PULLUP);
  
  Serial.begin(115200); 

  // Trigger ONLY on RISING edge of Pin A to get 1:1 pulse count
  attachInterrupt(digitalPinToInterrupt(pinA), handlePulse, RISING);
  
  Serial.println("Reading 600 Pulses Per Revolution...");
}

void loop() {
  static long lastPrintedPulses = 0;
  
  if (pulseCount != lastPrintedPulses) {
    Serial.print("Pulses: ");
    Serial.println(pulseCount);
    
    lastPrintedPulses = pulseCount;
  }
}

// Simple ISR to count pulses and determine direction
void handlePulse() {
  // Check Pin B when Pin A rises to determine direction
  if (digitalRead(pinB) == LOW) {
    pulseCount++;
  } else {
    pulseCount--;
  }
}