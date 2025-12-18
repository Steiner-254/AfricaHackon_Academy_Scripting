import textwrap

text = "It is good to learn Python before Christmas btw because - Python is an amazing programming language that is widely used for software engineering and more."
wrapped_text = textwrap.fill(text, width=50)
print(wrapped_text)