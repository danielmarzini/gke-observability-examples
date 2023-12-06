# gke-observability-examples


# Monitoring
## Prometheus
Run terraform code to set up the project and the cluster with Managed Service for Prometheus installed

## Exporters
Install additional exporters so to have additional metrics into Prometheus and Cloud Monitoring

### 1. Node Exporter
Node Exporter [docs page](https://cloud.google.com/stackdriver/docs/managed-prometheus/exporters/node_exporter)
```
kubectl apply -f https://raw.githubusercontent.com/GoogleCloudPlatform/prometheus-engine/4b43a23af211d9a0e474dfb014d3251273c1d934/examples/node-exporter/node-exporter.yaml
```

### 2. KubeStateMetrics
Kube State Metrics [docs page](https://cloud.google.com/stackdriver/docs/managed-prometheus/exporters/kube_state_metrics)

```
kubectl apply -f  https://raw.githubusercontent.com/GoogleCloudPlatform/prometheus-engine/d2d33b9806a10b08887bd629833ba232c440870a/examples/kube-state-metrics/kube-state-metrics.yaml
```

### 3. Kubelet/cAdvisor
Follow the [doc page](https://cloud.google.com/stackdriver/docs/managed-prometheus/exporters/kubelet-cadvisor) to enable Kubelet/cAdvisor exporter

# Dashboarding

Cloud Monitoring -> Dashboards -> Sample Library -> Import the followings:
- JVM Prometheus Overview
- Kubernetes Cluster Prometheus Overview
- Kubernetes Infrastructure Prometheus Overview
- Kubernetes Pod Prometheus Overview

### 4. JMX
Apply the PodMonitoring manifests adjusted to your deployment to start ingesting JMX metrics to the managed Prometheus
- within minutes the imported (before) JVM dashboard will start showing values

# HPA
Guide on [how to enable HPA to use Prometheus](https://cloud.google.com/stackdriver/docs/managed-prometheus/hpa)
kubectl apply -n monitoring -f https://raw.githubusercontent.com/GoogleCloudPlatform/k8s-stackdriver/master/custom-metrics-stackdriver-adapter/deploy/production/adapter_new_resource_model.yaml

```
export PROJECT_ID=YOUR_PROJECT
gcloud iam service-accounts create custom-metrics --project $PROJECT_ID

gcloud projects add-iam-policy-binding $PROJECT_ID\
  --member=serviceAccount:custom-metrics@$PROJECT_ID.iam.gserviceaccount.com \
  --role=roles/monitoring.viewer

gcloud projects add-iam-policy-binding $PROJECT_ID\
  --member=serviceAccount:custom-metrics@$PROJECT_ID.iam.gserviceaccount.com \
  --role=roles/monitoring.metricWriter

gcloud iam service-accounts add-iam-policy-binding --role \
  roles/iam.workloadIdentityUser --member \
  "serviceAccount:$PROJECT_ID.svc.id.goog[monitoring/custom-metrics-stackdriver-adapter]" \
  custom-metrics@$PROJECT_ID.iam.gserviceaccount.com

gcloud iam service-accounts add-iam-policy-binding --role \
  roles/monitoring.viewer --member \
  "serviceAccount:$PROJECT_ID.svc.id.goog[monitoring/custom-metrics-stackdriver-adapter]" \
  custom-metrics@$PROJECT_ID.iam.gserviceaccount.com

kubectl annotate serviceaccount --namespace monitoring \
custom-metrics-stackdriver-adapter \
iam.gke.io/gcp-service-account=custom-metrics@$PROJECT_ID.iam.gserviceaccount.com
```

### 5. Deployment
Apply the the Kubernetes manifest into the k8s directory in order.