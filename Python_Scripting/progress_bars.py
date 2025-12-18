from tqdm import tqdm
import time

# Example of a long-running task with a progress bar
for i in tqdm(range(100)):
    time.sleep(0.1)  # Simulate a task taking some time
    