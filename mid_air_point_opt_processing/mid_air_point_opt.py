import socket
import math
import random
import numpy as np

# More info about BO is here:
# https://github.com/fmfn/BayesianOptimization
from bayes_opt import BayesianOptimization

##### The function for optimization 
##### No need to change here as long as you don't include more parameters
def optimize_function(gain, h_point, m_deg):
    global iteration_count
    global sample_times

    # Send the parameters to processing 
    send_data = bytes([int(gain)])
    conn.sendall(send_data)
    send_data = bytes([int(h_point)])
    conn.sendall(send_data)
    send_data = bytes([int(m_deg)])
    conn.sendall(send_data)
    
    # Now, we start collecting data sent from processing
    rec_count = 0
    received_all = []
    while(rec_count< sample_times):
        data = conn.recv(1024)
        if data: 
            received = round(float(data.decode("utf-8")) , 0)
            received_all.append(received)
            rec_count += 1
    #print (received_all)
    received_all = np.array(received_all)

    # The received data 0-2 is the completion times, received data 3 is the user feedback
    # The final value will be the average of the completion times
    # plus bonus/penalty based on user's feedback
    final_value = np.average(received_all[0:3])
    # We give some bonus (shorten the averaged completion time) if the user rate 5 or 4
    if (received_all[3] == 5):
        final_value -= 1000
    elif (received_all[3] == 4):
        final_value -= 500
    # On the other hand, we give penalty (prolong the averaged completion time) 
    # if the user rate 1 - 3
    elif (received_all[3] == 3):
        final_value += 500
    elif (received_all[3] == 2):
        final_value += 1000
    elif (received_all[3] == 1):
        final_value += 2000

    final_value *= -1 # Because we want to "OPTIMIZE" the value, so make it negtive

    # You may print the final value by uncomment this line
    #print("final is %.2f" %final_value)
    return final_value 
    


##### Main function start here
HOST = '' 
PORT = 50007              # Arbitrary non-privileged port

# Sound parameters and setup server
audio = []
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.bind((HOST, PORT))
s.listen(1)
print ('Server starts, waiting for connection...')
conn, addr = s.accept()
# Now the connection is done
print('Connected by', addr)

# Every iteration will require 4 data from processing
sample_times = 4  

iteration_count = 0

### Setting parameter bounds
pbounds = {'gain': (60, 150), 'h_point': (10, 50), 'm_deg': (10,160)}

### Setup the optimizer 
optimizer = BayesianOptimization(
    f=optimize_function,
    pbounds=pbounds,
    random_state=1,
)

### Optimizing...
### init_points <- How many random steps you want to do
### n_iter <- How many optimization steps you want to take
optimizer.maximize(
    init_points=20,
    n_iter=20,
)

### Print the best
print(optimizer.max)

### If you want to print all the iterations, uncomment below 2 lines
#for i, res in enumerate(optimizer.res):
#    print("Iteration {}: \n\t{}".format(i, res))

# Close the server
conn.close()