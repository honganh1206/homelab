# Homelab

Customizing resource configuration without using templates or other tools like Helm using Kustomize.

MetalLB is a load balancer for bare-metal K8S (although we are still running K8S on Proxmox VM)

Using L2 mode means all traffic for a service IP goes to one node, and `kube-proxy` spreads the traffic to service pods. This is more like failover mechanism (different nodes take care of traffic when leader node is down) than implementing a load balancer.

## [Taints and Tolerations](https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/)

[Node affinity](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#node-affinity) allows us to constrain which nodes our Pod can be scheduled on based on node labels

Taints allow a node to repel a set of nodes.

## Effect

How a node should treat the pod that do not tolerate that taint

## Certificates

Two CA certificates and a temporary cert-manager Issuer.

```
SelfSigned Issuer       ← bootstrap mechanism, not a certificate
        │
        ▼
Root CA certificate     ← self-signed trust anchor
        │
        ▼
Intermediate CA certificate <- sign everyday certificates
        │
        ▼
Service/Ingress certificates
```

Issuer instructs cert-manager to generate a key pair (private - public) and let the new certificate sign itself.

Root CA is at top of the chain and signs itself.

Example: Hosting Grafana at `grafana.homelab.internal`

```
Homelab Root CA
      │
      │ signs
      ▼
Kubernetes Intermediate CA
      │
      │ signs
      ▼
grafana.homelab.internal
```

Steps: Bootstrap Self Issuer -> Create key pair for Root CA -> Install Root CA to K8S Secret -> Create Intermediate CA, signed by Root CA -> Create Grafana key-pair, signed by Intermediate CA. 

## Traefik

Ingress controller embedded in K3S. We enable access to our services running in our cluster throuugh Traefik ingress, instead of assigning them external IPs directly.
