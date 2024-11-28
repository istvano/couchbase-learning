# Start with a base image that includes Java 15
FROM eclipse-temurin:17-jre-noble

# Set environment variables for YCSB version and Couchbase SDK version
ENV YCSB_VERSION=2.0.5

# Set working directory
WORKDIR /ycsb

# Install curl and unzip
RUN apt-get update && apt-get install -y curl unzip && \
    curl -OLs https://github.com/couchbaselabs/ycsb-couchbase/releases/download/$YCSB_VERSION/ycsb-couchbase.zip && \
    unzip ycsb-couchbase.zip && \
    rm ycsb-couchbase.zip && \
    mv ycsb-couchbase/* . && \
    rmdir ycsb-couchbase && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN cp /ycsb/workloads/workloada /ycsb/workloads/workloadz && \
    sed -i \
    -e 's/requestdistribution=zipfian/requestdistribution=uniform/g' \
    -e 's/readproportion=0.5/readproportion=0.75/g' \
    -e 's/updateproportion=0.5/updateproportion=0.25/g' \
    /ycsb/workloads/workloadz    

RUN mv /ycsb/conf/db.properties /ycsb/conf/db.properties.orig

# Set default values for YCSB run script options
ENV WORKLOAD=a
ENV ONLY_LOAD=false
ENV ONLY_RUN=false
ENV RECORDS=1000
ENV OPERATIONS=1000
ENV TIME=0
ENV MANUAL_MODE=false
ENV ENABLE_STATS=true

# Copy the entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Set default command to run the entrypoint
ENTRYPOINT ["/entrypoint.sh"]