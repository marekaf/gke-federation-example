#!/bin/bash

PROJECT_ID="$(gcloud projects describe $(gcloud config get-value core/project -q) --format='get(projectNumber)')"
PROJECT_NAME="$(gcloud config get-value core/project -q)"
GCLOUD_USER=$(gcloud config get-value core/account)

#create-clusters
CLUSTERS=(test-eu test-br)
ZONES=(europe-west1-d southamerica-east1-b)

#create clusters
i=0
for CLUSTER_NAME in "${CLUSTERS[@]}"
do
  ZONE="${ZONES[$i]}"
  ((i++))
  gcloud container clusters create "${CLUSTER_NAME}" --zone "${ZONE}" --no-enable-autorepair --machine-type "n1-standard-1" --image-type "COS" --disk-size "100" --scopes "https://www.googleapis.com/auth/cloud-platform","https://www.googleapis.com/auth/compute","https://www.googleapis.com/auth/devstorage.read_only","https://www.googleapis.com/auth/ndev.clouddns.readwrite","https://www.googleapis.com/auth/logging.write","https://www.googleapis.com/auth/monitoring","https://www.googleapis.com/auth/servicecontrol","https://www.googleapis.com/auth/service.management.readonly","https://www.googleapis.com/auth/trace.append" --num-nodes "2" --network "default" --enable-cloud-logging --enable-cloud-monitoring --cluster-version=1.9
  gcloud container clusters get-credentials "${CLUSTER_NAME}" --zone "${ZONE}" --project "${PROJECT_NAME}"
  kubectl create clusterrolebinding cluster-admin-binding --clusterrole=cluster-admin --user=${GCLOUD_USER}
done

# go back to host cluster

CLUSTER_NAME=test-eu
ZONE=europe-west1-d
gcloud container clusters get-credentials "${CLUSTER_NAME}" --zone "${ZONE}" --project "${PROJECT_NAME}"

HOST_CLUSTER_CONTEXT=gke_mab-testing_europe-west1-d_test-eu
kubefed init federation --host-cluster-context="$HOST_CLUSTER_CONTEXT" --dns-provider="google-clouddns" --dns-zone-name="infra.marekbartik.com."

kubectl create namespace default --context=federation

kubefed join gke_mab-testing_southamerica-east1-b_test-br --host-cluster-context="$HOST_CLUSTER_CONTEXT"

# set some nice context names
kubectl config set-context federation-eu --cluster gke_mab-testing_europe-west1-d_test-eu       --user gke_mab-testing_europe-west1-d_test-eu
kubectl config set-context federation-br --cluster gke_mab-testing_southamerica-east1-b_test-br --user gke_mab-testing_southamerica-east1-b_test-br

# dunno if this is necessary
kubectl create clusterrolebinding cluster-admin-binding --clusterrole=cluster-admin --user=mab@ext.revolgy.com --context=federation-br
kubectl create clusterrolebinding cluster-admin-binding --clusterrole=cluster-admin --user=mab@ext.revolgy.com --context=federation-eu

# you might need to delete and create some clusterroles,clusterrolebindings,serviceaccounts
kubefed --context=federation join federation-eu --host-cluster-context="federation-eu"
kubefed --context=federation join federation-br --host-cluster-context="federation-eu"
kubectl get clusters --context=federation

kubectl apply -f deployment.yaml -n default --context=federation

kubectl get pods --context=federation-br -n default
kubectl get pods --context=federation-eu -n default

kubectl apply -f service.yaml -n default --context=federation

kubectl run --context=federation-br curl-test --image=radial/busyboxplus:curl --rm  -i -- sh -c 'curl nginx'
kubectl run --context=federation-eu curl-test --image=radial/busyboxplus:curl --rm  -i -- sh -c 'curl nginx'

#delete clusters
#i=0
#for CLUSTER_NAME in "${CLUSTERS[@]}"
#do
#  ZONE="${ZONES[$i]}"
#  ((i++))
#  gcloud container --project "${PROJECT_ID}" clusters delete "${CLUSTER_NAME}" --zone "${ZONE}"
#done
#
# kubectl delete ns federation-system
