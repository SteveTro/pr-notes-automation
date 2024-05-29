FROM python:3.9-slim-buster

# Install git
RUN apt-get update && apt-get install -y git

# Install Python packages
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Set the working directory
WORKDIR /github/workspace

# Copy your Python script into the container
COPY entrypoint.py /entrypoint.py

# Make the script executable (optional for Python)
RUN chmod +x /entrypoint.py

ENTRYPOINT ["python", "/entrypoint.py"]