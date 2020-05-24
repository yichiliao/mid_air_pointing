import processing.net.*; 
import processing.serial.*;
Serial arduino;
Client myClient;

// Basic render parameters
int top_bar = 200;
int low_bar = 550;
int low_bar_height = 60;
int top_bar_height = 30;
int answer_begin = 140;
int answer_begin_y = 670;
int answer_width = 40;
int answer_interval = 100;

// ===== Parameters for determining the rendering cursor position ===== 
// and the related handling communication with Arduino
int cur_time = millis();
int cur_det = 50;     // The current detecting distance (from Arduino)
int pre_det = 50;     // The previous detecting destance
int dx = 0;           // cur_det - pre_det ---> diff of x
int render_pos = 200; // This is the current y position of the cursor. It starts from 200 (top).
float dx_gain = 10.7; // ***** Optimizing parameter: the gain function *****
int direction = -1;   // Direction remains -1
String readin;        // It takes in the detection from Arduino
int sample_times = 3; // Every iteration, we take 3 trials into account

// ===== Paremeters for handling if the cursor reaches target ===== 
// The condition of reach a target: 
// the cursor has to go inside the target bar and remains more than (reach_threshold) ms
boolean on_target = false;       // If the cursor is on target bar right now
boolean prev_on_target = false;  // It the cursor is on target bar at previous timestamp
boolean reached = false;         // If the cursor is on target, and remains > reach_threshold ms, it has reached
boolean prev_reached = false;    // If the cursor reached the target at previous timestamp
int target_timer = 0;            // When the cursor first arrives the target bar (!pre_on_target && on_target), start counting time
int reach_threshold = 500;       // The threshold for detecting if it has reached (unit: ms)

// ===== Parameters related to render haptic feedback ===== 
// The feedback will be generate before the cursor arrives the target
// More specifically, the motor will move when it is (hit_threshold) pixels before the target bar
int distance_to_target = 200;    // This parameter keep tracking the distance between the cursor and the target bar
boolean hit = false;             // If the haptic cue is sent or not. It should render just once per trial
int hit_threshold = 38;          // **** Optimizing parameter: how many pixels pior to the target zone should generate feedback
boolean sent = false;            // When starting off-line mode (no server), we need to send motor degree to Arduino for just once

// ===== Parameters for handling returning the waiting line and task completion ===== 
// After the cursor reached (arrives target + stay there for > reach_threshold), 
// It should return to the waiting line (top bar). Once it has returned, a trial is completed. 
// If the user completed (sample_timesthe) trials, an iteration is done. 
boolean on_waitline = false;        // If the cursor is on the waiting line right now
boolean prev_on_waitline = false;   // If the cursor is on the waiting line at previous timestamp
int moving_timer = 0;               // We record the timestamp as the cursor leaves the waiting line
boolean counting = false;           // When the cursor leaves the waiting line, it start counting
int task_time = 0;                  // The completion time of one trial (the completion timestamp - moving_timer)
int[] tasks_time = {0,0,0};         // The overall completion time of all trials. The length is 3 because current sample_times = 3 
int completion_count = 0;           // How many completed trials so far for this iteration.

// ===== Parameters for handling rating feedback as an iteration is done =====
// User has to rate the feedback by 1, 2, 3, 4, 5. 
// 1 is the worst, 5 is the best
boolean answered = true;            // If the user has answered the question (rate feedback) or not
int user_rating = 0;                // The user's rating
boolean ready_to_send_py = false;   // If the user has rated, now we are ready to send everything to python server      

// ===== Parameters for reading the parameters sent from python server =====
// Before every iteration, the python server sends the parameters to processing. 
// Parameters including: dx_gain, hit_threshold, and motor_target_degree (the level of servo motor feedback)
int dataIn = 0;                     // A parameter for reading the int from python
int motor_target_degree = 56;       // **** Optimizing target: the motor target degree when it is activated

// ===== Parameters for pausing the system for 1.5s after an iteration starts =====
// Why we need this? Because we need to reset the current detection and current cursor position from time to time
// The easiest way is asking the user to leave the sensor's detecting range and reset the parameters before every iteration
int wait_for_return_counter = 0;    // Once an iteration starts (read the input from python), we start timing
boolean wait_for_return = false;

// ===== Just for you to try out parameters without a python backend server =====
// Turn the parameter to false, you can render and try out
// When the parameter is true, it is expecting a ready server
boolean if_connect_python = true;

void setup() 
{
  size(800, 800);
  // Load the shape
  println ("<START>");
  println (Serial.list());
  println ("<END>");
  arduino = new Serial (this, "/dev/cu.usbmodem146101", 9600);
  if (if_connect_python)
  {myClient = new Client(this, "127.0.0.1", 50007);} // Starting connection
}

void draw() 
{
  if (if_connect_python)
  {
    if (myClient.available() > 0) 
    {
       dataIn = myClient.read();
       dx_gain = float(dataIn)/10; 
       print("Reset gain function: ");
       println(dx_gain);
     
       dataIn = myClient.read();
       hit_threshold = dataIn;
       print("Reset hit point: ");
       println(hit_threshold);
     
       dataIn = myClient.read();
       motor_target_degree = dataIn;
       print("Reset motor degree: ");
       println(motor_target_degree);
       send_to_arduino(motor_target_degree);
       delay(100);
       
       wait_for_return_counter = millis();
       wait_for_return = true;
    }
  }
  else if (!sent)
  {
    send_to_arduino(motor_target_degree);
    sent = true;
  }
  
  if (millis() - wait_for_return_counter > 1500 && wait_for_return)
  {
    render_pos = 200; 
    cur_det = 50;
    pre_det = 50;
    wait_for_return = false;
  }
  
  background(220);
  fill(0,0,0);
  textSize(20);
  if (!reached && !wait_for_return)
  {text("to target", 300, 140);}
  else if (reached && !wait_for_return)
  {text("return", 300, 140);}
  else
  {text("let go and wait", 300, 140);}
  
  // Center where we will draw all the vertices
  fill(255,255,255);
  if (wait_for_return)
  {fill(255,0,0);}
  rect(230, top_bar, 240,top_bar_height);
  if (on_target && !reached)
  {fill(255,255,0);}
  else if (reached)
  {fill(255,0,0);}
  rect(230, low_bar, 240,low_bar_height);
  
  fill(255,255,255);
  rect(550,140,60,30);
  fill(0,0,0);
  text("reset",554,162);
  
  // update the cursor position based on the value sent from Arduino
  if (!wait_for_return)
  {
    if (arduino.available()>0)
    {
      readin = arduino.readStringUntil('\n');
      if (readin != null)
      {
        cur_det = int(float(readin));
        dx = cur_det - pre_det;
        render_pos += int(dx_gain * dx * direction);
      
        pre_det = cur_det;
      }
    }
  }
  fill(0,0,0);
  rect(230,render_pos,240,5);
  
  if (answered)
  {
    distance_to_target = low_bar - render_pos;
    if ((distance_to_target < hit_threshold) && !hit)
    {
      hit();
      hit = true;
    }
  
    // Update the status based on top bar
    // Check if the cursor arrives/leaves the waiting line
    if (render_pos  < top_bar + top_bar_height)  // When the cursor reaches waiting line
    {
      on_waitline = true;  // modify the status so we know it's on waiting line
      reached = false;     // also, reached turns to false
    }
    else  // if the cursor leaves the waiting line
    {on_waitline = false;}
    if (prev_on_waitline && !on_waitline) // this means, the cursor just leaves the waiting line
    {
      moving_timer = millis();     // start counting time
      counting = true;             // also turn the counting flag as true
    }
  
    // Update the status based on low bar
    // Check if the cursor arrives/leaves the target bar
    if (render_pos > low_bar && render_pos < low_bar + low_bar_height) // now it's on target
    {on_target = true;}
    else    // now it's not on target
    {on_target = false;}
  
    if (!prev_on_target && on_target)      // which means it just arrives the target. We start counting
    {target_timer = millis();}
    else if (prev_on_target && on_target)  // if it remains on target. we check if this has last for more than 500 ms
    {
      if (millis() - target_timer > reach_threshold)
      {reached = true;}    // Now, we change the overall status into reached. the cursor can return
    }
  
    // If the cursor finishes a task and return, we stop counting time and print out
    if (prev_reached && !reached && counting)
    {
      task_time = millis() - moving_timer;
      tasks_time[completion_count] = task_time;
      counting = false;
      hit = false;
      if (completion_count==sample_times-1)
      { 
        println("completing one iteration ");
        completion_count = 0;
        answered = false;
      }
      else
      {completion_count += 1;}
    }
  }
  
  if (counting &&  (millis() - moving_timer> 6000))
  {
    println("task failed");
    for (int count = 0; count< sample_times; count += 1)
    {tasks_time[count] = 6500;}
    user_rating = 1;
    completion_count = 0;
    ready_to_send_py = true;
    counting = false;
    hit = false;
  }
  
  if (!answered)
  {
    fill(0,0,0);
    text("rate the haptic cue",250, 655);
    fill(255,255,255);
    for (int count=0; count < 5; count += 1)
    {rect(answer_begin + count * answer_interval, answer_begin_y, answer_width, answer_width);}
    fill(0,0,0);
    for (int count=0; count < 5; count += 1)
    {text(Integer.toString(count+1), answer_begin + count * answer_interval + 0.35 * answer_width, answer_begin_y + 0.7 * answer_width);}
    
    if(mousePressed)
    {
      if(mouseX>answer_begin && mouseX <answer_begin + answer_width 
      && mouseY>answer_begin_y && mouseY <answer_begin_y+answer_width)
      {
        user_rating = 1;
        answered = true;
        ready_to_send_py = true;
      }
      if(mouseX>answer_begin+ 1*answer_interval && mouseX <answer_begin+ 1*answer_interval + answer_width 
      && mouseY>answer_begin_y && mouseY <answer_begin_y+answer_width)
      {
        user_rating = 2;
        answered = true;
        ready_to_send_py = true;
      }
      if(mouseX>answer_begin+ 2*answer_interval && mouseX <answer_begin+ 2*answer_interval + answer_width 
      && mouseY>answer_begin_y && mouseY <answer_begin_y+answer_width)
      {
        user_rating = 3;
        answered = true;
        ready_to_send_py = true;
      }
      if(mouseX>answer_begin+ 3*answer_interval && mouseX <answer_begin+ 3*answer_interval + answer_width 
      && mouseY>answer_begin_y && mouseY <answer_begin_y+answer_width)
      {
        user_rating = 4;
        answered = true;
        ready_to_send_py = true;
      }
      if(mouseX>answer_begin+ 4*answer_interval && mouseX <answer_begin+ 4*answer_interval + answer_width 
      && mouseY>answer_begin_y && mouseY <answer_begin_y+answer_width)
      {
        user_rating = 5;
        answered = true;
        ready_to_send_py = true;
      } 
    }
  }
  if (mousePressed)
  {
    if(mouseX>550 && mouseX <610 && mouseY>140 && mouseY <170)
    {
      render_pos = 200;
      cur_det = 50;
      pre_det = 50;
      println("reset position");
      delay(100);
    }
  }
  
  if (ready_to_send_py && if_connect_python)
  {
    for (int count = 0; count < sample_times; count += 1)
    {
      println (str(tasks_time[count]));
      myClient.write(str(tasks_time[count]));
      delay(20);
    }
    myClient.write(str(user_rating));
    ready_to_send_py = false;
  }
  
  prev_reached = reached;
  prev_on_target = on_target;
  prev_on_waitline = on_waitline;
}

void send_to_arduino (int num)
{
  arduino.write('b');
  String str_num = str(num);
  for (int count = 0; count < str_num.length(); count+=1)
  {arduino.write(str_num.charAt(count));}
  arduino.write('e');
}

void hit ()
{
  arduino.write('h');
}
