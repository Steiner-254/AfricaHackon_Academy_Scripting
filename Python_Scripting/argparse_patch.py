import argparse

parser = argparse.ArgumentParser(description="A simple script that greets the user.")
parser.add_argument("name", type=str, help="Your name")
args = parser.parse_args()

print(f"Hello, {args.name}!")
