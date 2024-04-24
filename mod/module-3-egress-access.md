# Identify and Define Egress Access

This is step 2 of implementing egress access controls.

Before writing any policies or creating any network sets, it's a best practice to spend time identifying what external access your workloads require.

Are there multiple pods or namespaces that need access to the same external resources?
How can you best limit the scope of egress policies?

Identify Egress Access
============

At the moment, you're not very familiar with the installed hipstershop application, and have no idea if/what external access it may require.


This is where Calico's observability features are invaluable.

Log into Calico by copying the token from the ```Cluster CLI``` tab on the top-left.

Calico includes a cluster visualization tool: **Dynamic Service and Threat Graph**

Dynamic Service and Threat Graph provides a point-to-point, topographical representation of traffic within a cluster.

This shows traffic flows, color-coded traffic action (denied or allowed), and allows you to filter views to focus on a cluster view, namespace, or service.

This is valuable when defining, applying, and reviewing network policy within a cluster because it is very easy to visualize dependencies and interactions between namespaces, pods, and microservices, and assess the impact of any network policy changes.

The dynamic service and threat graph also automatically filters flow logs, making it easy to view traffic flow metadata.

Double-click on the hipstershop namespace, and it should zoom in to show all workloads within the namespace:

   ![Service graph](../assets/module-2/hipstershop-service-graph.png)

You should see that there are two resources communicating with the *public network*: ```kube-system``` namespace and the ```adservice``` service.

# **Use the flow logs table to find out what the adservice is communicating with.**

Click on the flow line between *adservice* and *public network* to filter the flows table, or use this filter:

```(source_namespace = "hipstershop") AND (dest_namespace = "-")```

You should see:
```dest_domains: cloudprofiler.googleapis.com```


Even though we have a default deny policy, the ```action: allow``` is because the default deny policy is *staged*.
Therefore the default Kubernetes behavior is occuring, which is to allow.

```policies: 0|security|security.security-default-pass|pass|0, 1|platform|platform.platform-default-pass|pass|0, 2|default|default.staged:default-deny|deny|-1, 3|__PROFILE__|__PROFILE__.kns.hipstershop|allow|0```

Kibana Dashboard and Elasticsearch Logs
================

Kibana is the frontend for Calico Cloud Elasticsearch, which is the logging infrastructure that centrally stores logs from all managed clusters. Kibana provides an interface to explore Elasticsearch logs and gain insights into workload communication traffic volume, performance, and other key aspects of cluster operations. Log data is also summarized in custom dashboards.

To access the Elastic Logs interface you will need a password.

In the ```Cluster CLI``` tab, enter the following command:

```bash
kubectl -n tigera-elasticsearch get secret tigera-secure-es-elastic-user -o go-template='{{.data.elastic | base64decode}}' && echo
```
Copy the password and enter it on the ```Dashboards``` tab.
The username is ```elastic```.

Sign in.

Go to Analytics > Dashboard.

Create an index pattern for ```tigera_secure_ee_flows.*```

We are going to add 3 visualizations.

Create visualization 1:

Choose:
* Bar vertical stacked - tigera_secure_ee_flows.*
* Horizontal axis - Top values of dest_domains
* Vertical axis - Count of records
* Break down by - Top values of source_name_aggr

Add a filter:
* source_name_aggr: is one of, multitool, adservice-

Save and return.

Create visualization 2:

Choose:
Table - tigera_secure_ee_flows.*
Rows:
* Top values of action
* Top values of source_name_aggr
* Top values of dest_name_aggr
* Top values of destination.ip
* Top values of dest_domains

Add a filter:
* source_namespace: is one of, default, hipstershop

Save and return.

Create visualization 3:

Choose:
Pie - tigera_secure_ee_flows.*
Slice by:
* Top values of action
* Top values of source_name_aggr
* Top values of dest_domains
Size by:
  * Count of records

Add a filter:
* source_name_aggr: is one of, multitool, adservice-

Save and return.

**Save the dashboard!**



adservice labels
============

In the last module we discovered that the ```adservice``` needs to communicate with ```cloudprofiler.googleapis.com```.

Lets find out if the adservice has existing labels we can use, or whether we need to create some.

``` bash
kubectl get pods -n hipstershop --show-labels
```


The adservice has an ```app=adservice``` label key/value pair that we can use, that is unique to this service (important for limiting scope).

Verify that only this pod has the label applied:

```bash
kubectl get pods -A --show-labels | grep "app=adservice"
```

After completing the previous modules we know that:
* The *adservice* requires external communication to *cloudprofiler.googleapis.com*
* We can use the ```app=adservice``` label to select the *adservice* in our policy

A DNS policy allows you to limit what external resources the pods in your cluster can reach. To build this you need two pieces:
1. A `GlobalNetworkSet` with a list of approved external domains.
2. An egress policy that applies globally and references our `GlobalNetworkSet`.

Create networksets
============

Create a NetworkSet resource in the ```Cluster CLI``` tab:

``` bash
kubectl apply -f -<<EOF
kind: NetworkSet
apiVersion: projectcalico.org/v3
metadata:
  name: googleapis
  namespace: hipstershop
  labels:
    external-endpoints: googleapis
spec:
  nets: []
  allowedEgressDomains:
    - cloudprofiler.googleapis.com
    - '*.googleapis.com'
    - '*.google.com'
    - 'googleapis.com'
EOF
```


You can verify this has been applied in the ```Calico UI``` tab.

In the left-hand menu, navigate to NetworkSets.

You should see the ```googleapis``` network set visible.

![Network Sets](../assets/module-4/networksets.png)

From here you can manage the domains or IP blocks that the network set references.

Create DNS policy
============

Create a DNS policy resource in the ```Cluster CLI``` tab:

```bash
kubectl apply -f -<<EOF
apiVersion: projectcalico.org/v3
kind: NetworkPolicy
metadata:
  name: security.hipstershop-googleapis-egress
  namespace: hipstershop
spec:
  tier: security
  order: 11
  selector: app == "adservice" || run == "multitool"
  serviceAccountSelector: ''
  egress:
    - action: Allow
      source: {}
      destination:
        selector: external-endpoints == "googleapis"
  types:
    - Egress
EOF
```
Create global networksets
============

```yaml
kubectl apply -f -<<EOF
kind: GlobalNetworkSet
apiVersion: projectcalico.org/v3
metadata:
  name: global-trusted-domains
  labels:
    external-endpoints: global-trusted
spec:
  nets: []
  allowedEgressDomains:
    - '*.tigera.io'
    - tigera.io
EOF
```

Create global DNS policy
============

```yaml
kubectl apply -f -<<EOF
apiVersion: projectcalico.org/v3
kind: GlobalNetworkPolicy
metadata:
  name: security.global-trusted-domains
spec:
  tier: security
  order: 20
  selector: ""
  namespaceSelector: ""
  serviceAccountSelector: ""
  egress:
    - action: Allow
      source: {}
      destination:
        selector: external-endpoints == "global-trusted"
  doNotTrack: false
  applyOnForward: false
  preDNAT: false
  types:
    - Egress
EOF
```

The last step of the process is to thoroughly test to ensure everything is configured correctly.

**First, enforce the default-deny policy in the Policies Board.**

Click on the ```default-deny``` policy, then ```edit```, then ```Enforce```

Check the hipstershop is working
============

Go to the ```HipsterShop``` tab and place an order.


Simulate egress traffic - cloudprofilers.googleapis.com
============

For this test, we will use the ```multitool``` pod that was deployed with the hipstershop.

This pod has curl and netcat installed for testing network access.

First, let's test it as-is and see if it can access cloudprofiler.googleapis.com:

Multitool in the hipstershop namespace:

```bash
kubectl -n hipstershop exec -t multitool -- sh -c 'ping -c 3 cloudprofiler.googleapis.com'
kubectl -n hipstershop exec -t multitool -- sh -c 'curl -I --connect-timeout 3 cloudprofiler.googleapis.com 2>/dev/null | grep -i http'
```

Multitool in the default namespace:

```bash
kubectl exec -t multitool -- sh -c 'ping -c 3 cloudprofiler.googleapis.com'
kubectl exec -t multitool -- sh -c 'curl -I --connect-timeout 3 cloudprofiler.googleapis.com 2>/dev/null | grep -i http'
```

Simulate egress traffic - tigera.com
============


Now, any pod that doesn't have a more permissive egress policy will only be allowed to access 'tigera.io'. You can test this with our `multitool` pod in the `hipstershop` namespace.

Let's go into our multitool pod in the `hipstershop` namespace and try to connect it to a few domains (tigera.io and github.com):

```bash
kubectl -n hipstershop exec -t multitool -- sh -c 'ping -c 3 tigera.io'
kubectl -n hipstershop exec -t multitool -- sh -c 'curl -I --connect-timeout 3 tigera.io 2>/dev/null | grep -i http'
kubectl -n hipstershop exec -t multitool -- sh -c 'ping -c 3 github.com'
kubectl -n hipstershop exec -t multitool -- sh -c 'curl -I --connect-timeout 3 github.com 2>/dev/null | grep -i http'
```

Test from the default namespace:
```bash
kubectl exec -t multitool -- sh -c 'ping -c 3 tigera.io'
kubectl exec -t multitool -- sh -c 'curl -I --connect-timeout 3 tigera.io 2>/dev/null | grep -i http'
kubectl exec -t multitool -- sh -c 'ping -c 3 github.com'
kubectl exec -t multitool -- sh -c 'curl -I --connect-timeout 3 github.com 2>/dev/null | grep -i http'
```
Observability
============

If the policy is working correctly we should see something like this in the dynamic service and threat graph:

   ![Service graph](../assets/module-5/service-graph.png)

The kibana dashboard should also show the impact of the policies on egress traffic:

   ![Kibana Dashboard](../assets/module-5/kibana-dashboard.png)



---

[:arrow_right: Container Security and Calico Security Events](/mod/module-4-security-events.md)     <br>

[:arrow_left: Deploy an Application](/mod/module-2-deploy-application.md) <br>
[:leftwards_arrow_with_hook: Back to Main](/README.md)  