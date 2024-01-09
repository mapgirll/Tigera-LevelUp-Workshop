Teams implementing the Azure Well-Architected Framework, and using the [Hub and Spoke](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/hub-spoke-network-topology) network topology often rely on the [Azure Firewall to inspect traffic](https://learn.microsoft.com/en-us/azure/architecture/guide/aks/aks-firewall) coming from Azure Kubernetes Service ([AKS](https://www.tigera.io/learn/guides/kubernetes-security/aks-security/)) clusters. However, they face challenges in precisely identifying the origin of that traffic as it traverses the Azure Firewall. By default, traffic leaving a Kubernetes cluster is not assigned a meaningful network identity that can be used to associate it with the application it came from.

Kubernetes is built to be dynamic, enabling workloads to continually scale up and down across different cluster nodes. As a result, they often use new IP addresses on the network or in some cases the source of traffic leaving the cluster appears to originate from the IP address of cluster nodes, which are also scaling up and down. You find yourself in a situation where you have to permit extensive network CIDRs through firewalls in order to adapt to the frequently changing and ephemeral characteristics of Kubernetes workloads. Security teams usually do not favor or approve of that approach.

[Egress Gateways with Calico](https://docs.tigera.io/calico-enterprise/latest/networking/egress/egress-gateway-azure) allow you to identify the Kubernetes namespaces and pods associated with egress traffic outside of your clusters. This makes it easy to know the source of traffic to be inspected by the Azure Firewall. Understanding the source of application traffic leaving the Azure Kubernetes Service cluster and passing through the Azure firewall is crucial for several important reasons:

1.  **Security and Compliance:** Identifying the source of outbound traffic helps ensure that only authorized applications and services are communicating with external resources. It allows administrators to enforce proper security measures, preventing unauthorized access and potential data breaches. This understanding is essential for compliance with industry regulations and data protection standards.
2.  **Troubleshooting and Debugging:** When an issue arises with outbound traffic, knowing the source allows for quick troubleshooting and debugging. Administrators can pinpoint the exact application or namespace responsible for the traffic, making it easier to identify and resolve problems efficiently.
3.  **Billing and Cost Management:** With accurate information about the sources of egress traffic, organizations can better manage costs and optimize their cloud resources. They can identify which applications contribute most to egress traffic and make informed decisions on resource allocation and billing.

# Solution Overview
-----------------

Our goal is to address challenges in pinpointing the source of traffic as it exits the cluster and traverses an external firewall, using [Egress Gateways](https://docs.tigera.io/calico-enterprise/latest/networking/egress/egress-gateway-azure) for Calico.

![](https://www.tigera.io/app/uploads/2023/09/Enabling-Workload-Level-Security-for-AKS-with-Azure-Firewall-and-Calico-Egress-Gateway-1.png)

This diagram illustrates our hub-spoke network design and the specific Azure resources used in our reference architecture. Each Spoke VNET shares its Egress Gateway address prefixes with the Azure Route Server located in the Hub VNET, ensuring seamless integration with the Azure network.

![](https://www.tigera.io/app/uploads/2023/09/Enabling-Workload-Level-Security-for-AKS-with-Azure-Firewall-and-Calico-Egress-Gateway-2.png)

[Egress traffic from Kubernetes](https://docs.projectcalico.org/about/about-kubernetes-egress) workloads can be directed through specific Egress Gateways (or none at all), guided by advanced [Egress Gateway Policy](https://docs.tigera.io/calico-enterprise/latest/networking/egress/egress-gateway-azure#configure-a-namespace-or-pod-to-use-an-egress-gateway-egress-gateway-policy-method) settings. This configuration creates a distinct network identity suitable for Azure firewall rule settings.

# Set up Azure and EGW environment
------------

## Step 1 - Use Terraform to create environment

We’ll use Terraform, an infrastructure-as-code tool, to deploy this reference architecture automatically. We’ll walk you through the deployment process and then demonstrate how to utilize Egress Gateways with Calico.

### Prerequisites

For this walkthrough, you need the following:

*   An Azure account
*   [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli)
*   [kubectl](https://kubernetes.io/docs/tasks/tools/)
*   [terraform](https://learn.hashicorp.com/tutorials/terraform/install-cli)

### Step 1: Log in to your Azure account

```bash 
az login
```

### Step 2: Check out and deploy the Terraform blueprint

Make sure that you completed the prerequisites above and cloned the Terraform [blueprint](https://github.com/tigera-solutions/azure-hub-spoke-aks-egress-gateways/tree/main) by running the following command in a local directory:

``` bash
git clone https://github.com/tigera-solutions/azure-hub-spoke-aks-egress-gateways.git
```

Navigate to the [azure](https://github.com/tigera-solutions/azure-hub-spoke-aks-egress-gateways/tree/main/azure) subdirectory and then deploy the infrastructure.

If the names “demo-hub-network” and “demo-spoke-networks” are already taken, you will want to edit the [variables.tf](https://github.com/tigera-solutions/azure-hub-spoke-aks-egress-gateways/blob/main/azure/variables.tf) file in Terraform to use custom names for your Hub and Spoke Azure Resource Groups.

``` bash
cd azure
terraform init
terraform apply
```

Update your kubeconfig with the AKS cluster credentials.

``` bash
az aks get-credentials --name spoke1-aks --resource-group demo-spoke-networks --context spoke1-aks
```

Verify that Calico is up and running in your AKS cluster.

```bash
kubectl get tigerastatus
```

```
NAME        AVAILABLE   PROGRESSING   DEGRADED   SINCE
apiserver   True        False         False      9m30s
calico      True        False         False      9m45s
```

### Step 3: Link your AKS Cluster to Calico Cloud

Join the AKS cluster to [Calico Cloud](https://www.calicocloud.io/home)

![](https://www.tigera.io/app/uploads/2023/09/Enabling-Workload-Level-Security-for-AKS-with-Azure-Firewall-and-Calico-Egress-Gateway-3.gif)

Verify your AKS cluster is linked to Calico Cloud.

```bash
kubectl get tigerastatus
```

```NAME                            AVAILABLE   PROGRESSING   DEGRADED   SINCE
apiserver                       True        False         False      50m
calico                          True        False         False      49m
cloud-core                      True        False         False      50m
compliance                      True        False         False      49m
image-assurance                 True        False         False      49m
intrusion-detection             True        False         False      49m
log-collector                   True        False         False      50m
management-cluster-connection   True        False         False      49m
monitor                         True        False         False      49m
```

### Step 4: Enterprise-grade Egress Gateways for the Azure Kubernetes Service

Connect your AKS cluster to the Azure Route Server. Use the first two nodes in the AKS cluster as BGP route reflectors to manage and limit the number of peer connections effectively.

``` yaml
kubectl apply -f -<<EOF
apiVersion: projectcalico.org/v3
kind: BGPConfiguration
metadata:
  name: default
spec:
  logSeverityScreen: Info
  nodeToNodeMeshEnabled: false
  asNumber: 63400
---
kind: BGPPeer
apiVersion: projectcalico.org/v3
metadata:
  name: peer-with-route-reflectors
spec:
  nodeSelector: all()
  peerSelector: route-reflector == 'true'
---
apiVersion: projectcalico.org/v3
kind: BGPPeer
metadata:
  name: azure-route-server-a
spec:
  peerIP: 10.0.1.4
  reachableBy: 10.1.0.1
  asNumber: 65515
  keepOriginalNextHop: true
  nodeSelector: route-reflector == 'true'
---
apiVersion: projectcalico.org/v3
kind: BGPPeer
metadata:
  name: azure-route-server-b
spec:
  peerIP: 10.0.1.5
  reachableBy: 10.1.0.1
  asNumber: 65515
  keepOriginalNextHop: true
  nodeSelector: route-reflector == 'true'
EOF
```

Set up a highly available Calico Egress Gateway for Tenant0. All outgoing traffic from Tenant0 in the AKS cluster will have a static source IP address in the range of **10.99.0.0/29**. This information will be used to configure the Azure Firewall.

``` yaml
kubectl apply -f - <<EOF
---
apiVersion: v1
kind: Namespace
metadata:
  name: tenant0-egw
---
apiVersion: projectcalico.org/v3
kind: IPPool
metadata:
  name: tenant0-pool
spec:
  cidr: 10.99.0.0/29
  blockSize: 31
  nodeSelector: "!all()"
  vxlanMode: Never
---
apiVersion: operator.tigera.io/v1
kind: EgressGateway
metadata:
  name: tenant0-egw
  namespace: tenant0-egw
spec:
  logSeverity: "Info"
  replicas: 2
  ipPools:
  - name: tenant0-pool
  template:
    metadata:
      labels:
        tenant: tenant0-egw
    spec:
      terminationGracePeriodSeconds: 0
      nodeSelector:
        kubernetes.io/os: linux
      topologySpreadConstraints:
      - maxSkew: 1
        topologyKey: topology.kubernetes.io/zone
        whenUnsatisfiable: DoNotSchedule
        labelSelector:
          matchLabels:
            tenant: tenant0-egw
EOF
```

### Validate the Deployment and Review Results

Validate that the Azure Route Server peers are learning routes from the Azure Kubernetes Services cluster.

```bash
az network routeserver peering list-learned-routes \
  --resource-group demo-hub-network --routeserver hub-rs \
  --name spoke-rs-bgpconnection-peer-1
  ```

```bash
az network routeserver peering list-learned-routes \
  --resource-group demo-hub-network --routeserver hub-rs \
  --name spoke-rs-bgpconnection-peer-2
  ```

Each node in the cluster should have a /26 block from the default pod IP pool and /31 routes for each Calico Egress Gateway pods.

Turn off BGP advertisement for the default Calico IPPool and validate the default pod IP routes are no longer being learned by the Azure Route Server peers.

```bash
kubectl patch ippool default-ipv4-ippool --type='merge' -p '{"spec":{"disableBGPExport": true}}'
```

In a short while, you should see only the route announcements for the Egress Gateway.

```json
{
  "RouteServiceRole\_IN\_0": \[
    {
      "asPath": "63400",
      "localAddress": "10.0.1.5",
      "network": "10.99.0.2/31",
      "nextHop": "10.1.0.4",
      "origin": "EBgp",
      "sourcePeer": "10.1.0.4",
      "weight": 32768
    }
  \],
  "RouteServiceRole\_IN\_1": \[
    {
      "asPath": "63400",
      "localAddress": "10.0.1.4",
      "network": "10.99.0.2/31",
      "nextHop": "10.1.0.4",
      "origin": "EBgp",
      "sourcePeer": "10.1.0.4",
      "weight": 32768
    }
  \]
}
```

You can control the number of route announcements for Egress Gateway CIDRs by employing Calico BGP filters. The BGPFilter provided below enables the routing advertisements specifically for our egress gateways.

``` yaml
kubectl apply -f - <<EOF
kind: BGPFilter
apiVersion: projectcalico.org/v3
metadata:
  name: export-egress-ips
spec:
  exportV4:
    - action: Reject
      matchOperator: NotIn
      cidr: 10.99.0.0/29
EOF
```


Deploy a netshoot pod into the default namespace. Before executing the kubectl command, ensure that you are in the root directory of the project.

``` bash
cd ..
kubectl apply -f manifests/netshoot.yaml
```

Try making an outbound HTTP request to the www.tigera.io website to test the setup. If everything is configured correctly, you should receive a message from the firewall indicating that the request is blocked due to a lack of applicable firewall rules.

``` bash
kubectl exec -it -n default netshoot -- curl -v http://www.tigera.io
```

The request should be denied by the Azure Firewall. You should see a message similar to the following.

```
\*   Trying 178.128.166.225:80...
\* Connected to www.tigera.io (178.128.166.225) port 80 (#0)
> GET / HTTP/1.1
> Host: www.tigera.io
> User-Agent: curl/8.0.1
> Accept: \*/\*
>
< HTTP/1.1 470 status code 470
< Date: Sun, 03 Sep 2023 12:27:41 GMT
< Content-Length: 70
< Content-Type: text/plain; charset=utf-8
<
\* Connection #0 to host www.tigera.io left intact
Action: Deny. Reason: No rule matched. Proceeding with default action.
```

Let’s go ahead and activate the Calico Egress Gateways for the cluster. We’ll also specify that pods in the default namespace should use the tenant0-egw Egress Gateway.

``` bash
kubectl patch felixconfiguration default \
  --type='merge' -p '{"spec":{"egressIPSupport":"EnabledPerNamespaceOrPerPod"}}'
```

Set up the default namespace to utilize the Egress Gateway located in the tenant0-egw namespace.

``` bash
kubectl annotate ns default \
  egress.projectcalico.org/namespaceSelector="projectcalico.org/name == 'tenant0-egw'"
```

Egress traffic from Kubernetes can be directed through specific Egress Gateways, using Egress Gateway Policy or by annotating a namespace or pod.

Traffic is now allowed through the Azure Firewall because the incoming requests originate from a specific, recognized CIDR range assigned to the tenant0 Calico Egress Gateways.

``` bash
kubectl exec -it -n default netshoot -- curl -v http://www.tigera.io
```

You should now be able to get requests through the Azure Firewall. To verify, go to the Azure Firewall located in the hub resource group and select “Logs” under the Monitoring settings. Filter the Application log data to display the last 30 minutes. Look for entries showing that traffic originating from the 10.99.0.0/29 IP range has been successfully allowed to pass outbound through the Azure Firewall to www.tigera.io.

![](https://www.tigera.io/app/uploads/2023/09/Enabling-Workload-Level-Security-for-AKS-with-Azure-Firewall-and-Calico-Egress-Gateway-4.gif)

---
[:arrow_left: Web Application Firewall](/mod/module-5-waf.md)    <br>
[:leftwards_arrow_with_hook: Back to Main](/README.md)  