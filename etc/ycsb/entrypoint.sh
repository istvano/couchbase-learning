#!/bin/bash

# Path to properties file
DB_PROPERTIES_FILE="/ycsb/conf/db.properties"

# Check if a db.properties file has been mounted, if not create one
if [ ! -f "$DB_PROPERTIES_FILE" ]; then
    echo "Generating db.properties file from environment variables..."

    cat <<EOF > "$DB_PROPERTIES_FILE"
# Connection and Configuration Parameters
#
test.setup=site.ycsb.db.couchbase3.CouchbaseTestSetup
test.clean=site.ycsb.db.couchbase3.CouchbaseTestCleanup
statistics.class=site.ycsb.db.couchbase3.CouchbaseCollect
statistics.enable=${ENABLE_STATS:-false}
#
couchbase.hostname=${COUCHBASE_HOSTNAME:-127.0.0.1}
couchbase.bucket=${COUCHBASE_BUCKET:-bench}
couchbase.scope=${COUCHBASE_SCOPE:-bench}
couchbase.collection=${COUCHBASE_COLLECTION:-usertable}
couchbase.username=${COUCHBASE_USERNAME:-Administrator}
couchbase.password=${COUCHBASE_PASSWORD:-password}
# couchbase.ca.cert=${COUCHBASE_CA_CERT:-}
# couchbase.client.cert=${COUCHBASE_CLIENT_CERT:-}
# couchbase.keystore.type=${COUCHBASE_KEYSTORE_TYPE:-PKCS12}
# 0 - couchstore, 1 is magma
couchbase.bucketType=${COUCHBASE_BUCKET_TYPE:-0}
couchbase.replicaNum=${COUCHBASE_REPLICA_NUM:-1}
#couchbase.project=${COUCHBASE_PROJECT:-test-project}
#couchbase.database=${COUCHBASE_DATABASE:-cbdb01}
# 0 is good default, 3 is "Persist to Majority"
couchbase.durability=${COUCHBASE_DURABILITY:-0}
couchbase.adhoc=${COUCHBASE_ADHOC:-false}
# query service setting https://docs.couchbase.com/server/current/n1ql/n1ql-manage/query-settings.html#queryMaxParallelism
couchbase.maxParallelism=${COUCHBASE_MAX_PARALLELISM:-0}
couchbase.kvEndpoints=${COUCHBASE_KV_ENDPOINTS:-4}
# couchbase.sslMode=${COUCHBASE_SSL_MODE:-false}
couchbase.kvTimeout=${COUCHBASE_KV_TIMEOUT:-10}
couchbase.connectTimeout=${COUCHBASE_CONNECT_TIMEOUT:-10}
couchbase.queryTimeout=${COUCHBASE_QUERY_TIMEOUT:-75}
couchbase.mode=${COUCHBASE_MODE:-default}
couchbase.ttlSeconds=${COUCHBASE_TTL_SECONDS:-0}
couchbase.codec=${COUCHBASE_CODEC:-native}
couchbase.debug=${COUCHBASE_DEBUG:-false}
#couchbase.s3Bucket=bucket-name
#couchbase.dbLink=data_link
#couchbase.analyticsTimeout=300
#bench.schemaOnly=true
#columnar.importType=json
#bench.benchmark=ch2
#bench.benchQueryGroup=analytics
#bench.warehouseCount=10
#couchbase.eventing=timestamp.js
#
# Optional XDCR Cluster
#
#xdcr.hostname=1.2.3.4
#xdcr.bucket=ycsb
#xdcr.scope=_default
#xdcr.collection=_default
#xdcr.username=Administrator
#xdcr.password=password
#xdcr.bucketType=0
#xdcr.replicaNum=1
#xdcr.project=test-project
#xdcr.database=target01
#xdcr.durability=0
#xdcr.adhoc=false
#xdcr.maxParallelism=0
#xdcr.kvEndpoints=4
#xdcr.sslMode=true
#xdcr.kvTimeout=5
#xdcr.connectTimeout=5
#xdcr.queryTimeout=75
#xdcr.mode=default
#xdcr.ttlSeconds=0
#xdcr.external=true
#xdcr.eventing=timestamp.js
EOF
else
    echo "Using mounted db.properties file."
fi

# Build the YCSB command with options
CMD="bin/run.sh -w ${WORKLOAD:-a}"

# Add optional flags based on environment variables
[ "$ONLY_LOAD" = "true" ] && CMD="$CMD -l"
[ "$ONLY_RUN" = "true" ] && CMD="$CMD -r"
[ -n "$RECORDS" ] && CMD="$CMD -R $RECORDS"
[ -n "$OPERATIONS" ] && CMD="$CMD -O $OPERATIONS"
[ -n "$TIME" ] && CMD="$CMD -T $TIME"
[ "$MANUAL_MODE" = "true" ] && CMD="$CMD -M"
[ "$ENABLE_STATS" = "true" ] && CMD="$CMD -S"

# Run the final command
cat $DB_PROPERTIES_FILE
echo "Running YCSB command: $CMD"
eval "$CMD"
