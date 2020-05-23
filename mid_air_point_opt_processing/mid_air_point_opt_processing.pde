import processing.net.*; 
import processing.serial.*;
Serial arduino;
Client myClient;

int top_bar = 200;
int low_bar = 550;
int low_bar_height = 60;
int top_bar_height = 30;
int answer_begin = 140;
int answer_begin_y = 670;
int answer_width = 40;
int answer_interval = 100;

int cur_time = millis();
int cur_det = 50;
int pre_det = 50;
int dx = 0;

int render_pos = 200;
float dx_gain = 10.2;     // **** Optimizing target
int direction = -1;
String readin;

boolean sent = false;
boolean on_target = false;
boolean prev_on_target = false;
boolean reached = false;
boolean prev_reached = false;
int target_timer = 0;
int reach_threshold = 500; // unit: ms

int distance_to_target = 200;
boolean hit = false;
int hit_threshold = 30;   // **** Optimizing target
int sample_times = 3;

boolean on_waitline = false;
boolean prev_on_waitline = false;
int moving_timer = 0;
boolean counting = false;
int task_time = 0;
int[] tasks_time = {0,0,0}; 

int completion_count = 0;

boolean answered = true;
int user_rating = 0;
boolean ready_to_send_py = false;
float final_value = 0.0;

int dataIn = 0;
int motor_target_degree = 0;// **** Optimizing target

boolean if_connect_python = true;
int wait_for_return_counter = 0;
boolean wait_for_return = false;

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
       print("Reset sound point: ");
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
