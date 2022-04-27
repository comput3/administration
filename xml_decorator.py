"""Takes a function and its arguments as input and converts the text to xml

Args:
    func (function): The function 

Returns:
    list: an xml string with the function name as the tag information

Use: decorator
"""

def format_output(func):

    def wrapper(*args):
        return f'<{str(func.__name__)}>{str(func(*args)) or ""}</{str(func.__name__)}>'

    return wrapper
