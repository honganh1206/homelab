# Homelab

Customizing resource configuration without using templates or other tools like Helm using Kustomize.

MetalLB is a load balancer for bare-metal K8S (although we are still running K8S on Proxmox VM)

Using L2 mode means all traffic for a service IP goes to one node, and `kube-proxy` spreads the traffic to service pods. This is more like failover mechanism (different nodes take care of traffic when leader node is down) than implementing a load balancer.

## Storage

```
Physical disk
└── GPT partition
    └── LVM Physical Volume (PV)
        └── Volume Group (VG)
            └── Logical Volume (LV)
                └── Filesystem
                    └── Mounted directory
```

Rule of thumb for volume metadata: Allocate 1 MiB per 1 GiB present in the PV

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

> Fun fact: We did not specify which node will run `cert-manager` pods, so K3S scheduler examined the eligible nodes, filtered them based on constraints and decided k3sagent01 is the most eligible.

## Traefik

Ingress controller embedded in K3S. We enable access to our services running in our cluster throuugh Traefik ingress, instead of assigning them external IPs directly.

## Monitoring

We use the affinity rules to make Prometheus run on one agent node and Grafana on the other.

Labels (KV pairs) attached to targets and eventually metrics, used to querying/filtering monitoring data.

`__meta_` are internal labels from K8S APIs. They will be dropped unless interacted by `relabel_configs`.

A lot of relabeling to get scraping done well!

## Kube State Metrics (not metrics-server)

An agent that gets cluster-level metrics and exposes them via a Prometheus-compatible `/metrics` endpoint

Different from Prometheus Node Exporter (Expose host metrics)
