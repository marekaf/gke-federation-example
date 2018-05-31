

kubectl create deployment get-region --image=ulamlabs/get-region
kubectl scale deployment get-region --replicas=16
kubectl get deploy

kubectl create service nodeport get-region --tcp=80:80 --node-port=30040


