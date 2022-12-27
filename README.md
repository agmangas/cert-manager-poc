# Proof of concept of cert-manager and Let's Encrypt on GKE

A proof of concept of exposing L4 and L7 services to the Internet on [GKE](https://cloud.google.com/kubernetes-engine/) using [cert-manager](https://cert-manager.io/) for automatic SSL certificate management.

## Configuration of the DNS server

Please note that this proof of concept involves a **manual step**. 

First, you need to find the Load Balancer public IP that sits in front of the NGINX Ingress Controller:

```
kubectl get service/ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

Then, you need to update the DNS configuration of your domains (see `variables.tf`) by adding an `A` record pointing to the previous Load Balanacer public IP.