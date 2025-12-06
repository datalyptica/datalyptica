#!/bin/bash
# Spark K8s Native Mode Test Script

# Get pod IP for driver host placeholder replacement
POD_IP=$(hostname -i)

# Replace placeholder in config
sed "s/_DRIVER_HOST_PLACEHOLDER_/$POD_IP/" /opt/spark/conf/spark-defaults.conf > /tmp/spark-defaults-runtime.conf

# Submit Spark job in Kubernetes native mode
/opt/spark/bin/spark-submit \
  --master k8s://https://kubernetes.default.svc:443 \
  --deploy-mode client \
  --name "Spark-K8s-Aggressive-Test" \
  --properties-file /tmp/spark-defaults-runtime.conf \
  --conf spark.kubernetes.namespace=datalyptica \
  --conf spark.kubernetes.authenticate.driver.serviceAccountName=spark-driver \
  --conf spark.kubernetes.container.image=image-registry.openshift-image-registry.svc:5000/datalyptica/spark-iceberg:3.5.7 \
  --conf spark.executor.instances=2 \
  --conf spark.dynamicAllocation.enabled=true \
  --conf spark.dynamicAllocation.shuffleTracking.enabled=true \
  --conf spark.dynamicAllocation.minExecutors=1 \
  --conf spark.dynamicAllocation.maxExecutors=5 \
  --conf spark.dynamicAllocation.initialExecutors=2 \
  --jars /opt/spark/jars/iceberg/iceberg-spark-runtime-3.5_2.12-1.10.0.jar,/opt/spark/jars/iceberg/iceberg-nessie-1.10.0.jar,/opt/spark/jars/iceberg/bundle-2.28.11.jar,/opt/spark/jars/iceberg/url-connection-client-2.28.11.jar,/opt/spark/jars/iceberg/aws-java-sdk-bundle-1.12.772.jar,/opt/spark/jars/iceberg/hadoop-aws-3.4.1.jar \
  "$@"
