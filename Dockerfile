# Use the official OpenJDK 11 image as the base image
FROM openjdk:11

# Set environment variables for Node.js and npm
ENV NODE_VERSION 14
ENV NPM_VERSION 7

# Install dependencies and tools
RUN apt-get update && \
    apt-get install -y \
        bash \
        curl \
        jq \
        nodejs \
        npm && \
    rm -rf /var/lib/apt/lists/*

# Set the working directory to /app
WORKDIR /app

# Copy the Maven Wrapper script from the local directory into the image
COPY mvnw mvnw
COPY mvnw.cmd mvnw.cmd
COPY .mvn .mvn

# Copy the project files into the image
COPY pom.xml .
COPY src src

# Command to run on container start
CMD ["npm", "install"]
