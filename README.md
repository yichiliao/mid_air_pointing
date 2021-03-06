# mid_air_pointing
Optimizing the design parameters of a mid-air pointing task. 

## Hardware setup
Any arduino board, HC-SR04 ultrasonic distance sensor, and a micro servo motor. <br>
<br>
HC-SR04: Trig pin goes to Arduino digital output pin 9, Echo pin goes to Arduino digital output pin 10. <br>
Servo motor: the control pin goes to Arduino digital output pin 11.<br>

## Software setup
Environments:<br>
Python 3.x <br> 
Processing 3.x <br>
Arduino a fairly recent version. <br>

Required packages installation: <br>
pip3 install socket, numpy, bayesian-optimization<br>

Put the mid_air_point_opt_processing folder under Processing folder, and the mid_air_point_opt_arduino under Arduino folder. <br>
Upload the Arduino file onto your board. Execute mid_air_point_opt.py first, then mid_air_point_opt_processing.pde. 
<br>

In the processing file, this line <br>
boolean if_connect_python = true;<br>
Change true to false allows off-line testing.