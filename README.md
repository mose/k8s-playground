Kubernetes experiments
=========================

- get minikube and kubectl

The etherpad dir contains file for spawning an etherpad according to https://github.com/dockhippie/etherpad dockerfile

```
minikube start
kubectl apply -f etherpad/
open http://$(minikube ip):$(kubectl get svc etherpad -o jsonpath='{.spec.ports[].nodePort}')
minikube dashboard

# change some config param in etherpad/etherpad.yml
kubectl apply -f etherpad/

# when done
kubectl delete -f etherpad/
```
