# Identity-aware Microsegmentation with Hipstershop

To perform the microsegmentation we will need to know more about how the application communicates between the services. 

Source Service | Destination Service | Destination Port
--- | --- | ---
cartservice | redis-cart | 6379
checkoutservice | cartservice | 7070
checkoutservice | emailservice | 8080
checkoutservice | paymentservice | 50051
checkoutservice | productcatalogservice | 3550
checkoutservice | shippingservice | 50051
checkoutservice | currencyservice | 7000
checkoutservice | adservice | 9555
frontend | cartservice | 7070
frontend | productcatalogservice | 3550
frontend | recommendationservice | 8080
frontend | currencyservice | 7000
frontend | checkoutservice | 5050
frontend | shippingservice | 50051
frontend | adservice | 9555
loadgenerator | frontend | 8080
recommendationservice | productcatalogservice | 3550

# Use observability to identify workload communications

Use service graph / flow viz to find flows and labels.




This results in the following policy which we can now apply to the app-hipstershop tier using:

```bash
kubectl apply -f https://raw.githubusercontent.com/mapgirll/Tigera-LevelUp-Workshop/main/hipstershop/hipstershop-policy.yaml
```


Let's do a quick test. According to the above table redis-cart should accept communication only from cartservice over port 6379

First, we will exec cartservice to make sure that we can access redis-cart over port '6379'

```bash
kubectl exec -n hipstershop -it $(kubectl get -n hipstershop po -l app=cartservice -ojsonpath='{.items[0].metadata.name}') -- sh -c 'nc -zvw 3 redis-cart 6379'
```
The connection should be open

```
redis-cart (10.105.202.225:6379) open
```

Now we want to try to access redis-cart from an unauthorized pod in the hipstershop namespace (i.e. checkoutservice).

```bash
kubectl exec -n hipstershop -it $(kubectl get -n hipstershop po -l app=checkoutservice -ojsonpath='{.items[0].metadata.name}') -- sh -c 'nc -zvw 3 redis-cart 6379'
```

In this case, connection should timeout

```
nc: redis-cart (10.105.202.225:6379): Operation timed out
```


---

[:arrow_right: Container Security and Calico Security Events](/mod/module-4-security-events.md)     <br>

[:arrow_left: Deploy an Application](/mod/module-2-deploy-application.md) <br>
[:leftwards_arrow_with_hook: Back to Main](/README.md)  