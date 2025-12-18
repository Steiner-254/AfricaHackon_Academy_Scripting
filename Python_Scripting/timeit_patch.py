import timeit

def test():
    return sum(range(1000))

execution_time = timeit.timeit(test, number=1000)
print(f"Execution Time: {execution_time:.5f} seconds")
