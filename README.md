# Homelab

Customizing resource configuration without using templates or other tools like Helm using Kustomize.

MetalLB is a load balancer for bare-metal K8S (although we are still running K8S on Proxmox VM)

Using L2 mode means all traffic for a service IP goes to one node, and `kube-proxy` spreads the traffic to service pods. This is more like failover mechanism (different nodes take care of traffic when leader node is down) than implementing a load balancer.
