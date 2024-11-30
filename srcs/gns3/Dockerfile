# Use an official Python image as the base
FROM python:3.10-slim

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive

# Install necessary dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    software-properties-common \
    iputils-ping \
    net-tools \
    sudo \
    curl \
    libpcap-dev \
    qemu-system-x86 \
    dynamips \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Install GNS3 Server
RUN pip install gns3-server==2.2.42

# Expose default ports
EXPOSE 3080 22 80 443

# Set up volume for persistent data
VOLUME /data

# Set the default working directory
WORKDIR /data

# Start the GNS3 server by default
CMD ["gns3server", "--host", "0.0.0.0", "--port", "3080"]
