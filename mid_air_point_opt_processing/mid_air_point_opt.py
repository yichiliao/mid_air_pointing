import socket
import math
import wave
import struct
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

    # Send the activation point to processing
    send_data = bytes([int(gain)])
    conn.sendall(send_data)
    # Send the sound point to processing
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
            #print ('Temporal difference is %.2f' %t_diff)
            received_all.append(received)
            rec_count += 1
    # Don't take the last data point into account.
    # Because in some cases, the button is activated before the sound being played
    # In this case, the last data point will be without feedback (the processing is reseting itself)
    # Hence, we just ignore one data point for more consistency.
    #print (received_all)
    received_all = np.array(received_all)
    final_value = np.average(received_all[0:3])
    if (received_all[3] == 5):
        final_value -= 1000
    elif (received_all[3] == 4):
        final_value -= 500
    elif (received_all[3] == 3):
        final_value += 500
    elif (received_all[3] == 2):
        final_value += 1000
    elif (received_all[3] == 1):
        final_value += 2000

    final_value *= -1 #### Because we want to "OPTIMIZE" the value, so make it negtive

    #print("final is %.2f" %final_value)
    
    #print("End of one iteration")
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

# You may change these two values for trial different results
sample_times = 4  # How many presses will be taken into account per iteration

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
    init_points=10,
    n_iter=10,
)

### Print the best
print(optimizer.max)

### If you want to print all the iterations, uncomment below 2 lines
#for i, res in enumerate(optimizer.res):
#    print("Iteration {}: \n\t{}".format(i, res))

# Close the server
conn.close()