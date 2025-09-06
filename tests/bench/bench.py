def other_sum(x, y):
    return x + y

def sum_func(x, y):
    return other_sum(x, y)

def main():
    result = sum_func(60, 9)
    print(result)

if __name__ == "__main__":
    main()
