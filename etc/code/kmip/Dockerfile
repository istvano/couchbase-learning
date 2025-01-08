# Use an official Python runtime as a parent image
FROM python:3.9-slim

RUN apt update && apt upgrade && apt install --yes curl

# Set the working directory in the container
WORKDIR /app

# Install required packages
RUN pip install pykmip pycryptodome

# Run the Python script
ENTRYPOINT ["python"]
