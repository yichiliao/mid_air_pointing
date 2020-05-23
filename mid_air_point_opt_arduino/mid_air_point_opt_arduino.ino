#include <Servo.h>

Servo myservo;  // create servo object to control a servo

const int trigPin = 9;
const int echoPin = 10;
const int servoPin = 11;
const int ledPin = 13;

// defines variables
long duration;
float distance;

// parameters for moving average filter
#define WINDOW_SIZE 15
int idx = 0;
float sum = 0;
float readings[WINDOW_SIZE];
float averaged = 0;

// parameters for handling processing
char charin;
int valuein, value_sum;
bool received = false;

// parameters for servo
int servo_pos = 0;
int servo_target = 0;

void setup() {
  pinMode(trigPin, OUTPUT);
  pinMode(echoPin, INPUT); 
  myservo.attach(servoPin);
  Serial.begin(9600); // Starts the serial communication
  myservo.write(0);
  delay(100);
}

void loop() 
{
  if (Serial.available()) 
  {
    charin = Serial.read();
    if (charin == 'b')
    {
      value_sum = 0;
      received = true;
      while(true)
      {
        charin = Serial.read(); // read it and store it in val
        if (charin != 'e')
        {
          value_sum *= 10;
          valuein = charin - '0';
          value_sum += valuein;
          delay(10);
        }
        else
        {break;}
      }
    }
    else if (charin == 'h')
    {hit();}
  }
  if (received)
  {
    servo_target = value_sum; 
    received = false;
  }

  
  sum = sum - readings[idx];
  delay(10);
  // ultrasound trig
  digitalWrite(trigPin, LOW);
  delayMicroseconds(2);
  digitalWrite(trigPin, HIGH);
  delayMicroseconds(5);
  digitalWrite(trigPin, LOW);
  
  // receiving and calculate distance
  duration = pulseIn(echoPin, HIGH);
  distance= duration*0.034/2;
  // remove burst
  if (distance > 50)
  {distance = 50;}
  else if (distance < 0)
  {distance = 0;}
  
  readings[idx] = distance;
  sum = sum + distance;
  idx = (idx+1) % WINDOW_SIZE;
  averaged = sum / WINDOW_SIZE;
  //Serial.print("Distance: ");
  //Serial.print(distance);
  //Serial.print(" Averaged: ");
  Serial.println(averaged);
  delay(30);
}

void hit()
{
  for (servo_pos = 0; servo_pos <= servo_target; servo_pos += 1) 
  { 
    myservo.write(servo_pos);
    delay(3);
  }
  for (servo_pos = servo_target; servo_pos >= 0; servo_pos -= 1) 
  {
    myservo.write(servo_pos);
    delay(3);
  }
}
