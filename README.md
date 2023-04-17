# External DNS Dynamic IP

Simple cron job that fixes [external-dns](https://github.com/kubernetes-sigs/external-dns) when running behind a NAT with [MetalLB](https://metallb.universe.tf/).

By default, external-dns will inspect the value of a Service's external IP. If you use MetalLB and set up a port forward, this will not work as intended. External-dns will set DNS targets to your Service's internal IP instead of using your external IP.

This script will create a new `ConfigMap` called `external-dns-dynamic-ip` which will be updated dynamically if your IP changes. You can then assign this configmap to the `EXTERNAL_DNS_DEFAULT_TARGETS` external-dns env, and when your IP changes, the value will be updated and external-dns will be restarted so that it can update your DNS records.

## Deployment

1. Deploy the Kustomization manifests:

   ```shell
   kubectl apply -k https://github.com/gabe565/external-dns-dynamic-ip//kustomization
   ```

2. Update your external-dns deployment with the following env:

   ```yaml
   - name: EXTERNAL_DNS_DEFAULT_TARGETS
     valueFrom:
       configMapKeyRef:
         name: external-dns-dynamic-ip
         key: ip
   ```
