import platform

# Get system information
system_info = {
    'System': platform.system(),
    'Node': platform.node(),
    # 'Release': platform.release(),
    # 'Version': platform.version(),
    'Architecture': platform.architecture(),
}

# Print system information
for key, value in system_info.items():
    print(f"{key}: {value}")
