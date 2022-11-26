# Install K3D-Cluster

Crucial to using NGINX Ingress on K3D is disabling Traefik with ``--k3s-arg "--disable=traefik@server:0"``. This is installed by default and prevents the use of NGINX Ingress.
Also, port forwarding for the load balancer should be enabled by ``--port '8080:80@loadbalancer`` and ``--port '8443:443@loadbalancer``.

- install cluster: ``k3d cluster create demo --servers 1 --agents 1 --api-port 6443 --k3s-arg "--disable=traefik@server:0" --port 8080:80@loadbalancer --port 8443:443@loadbalancer --agents-memory=8G``

When installing the NGINX Ingress Controller, you can specify a default certificate right from the start. This is then also used for the Ingress resources that do not have their own certificate definition.
For this you first create a TLS-Secret with the certificate and the key. With a value file, here ``nginx-ingress-values.yaml``, you can tell the HELM chart of the NGINX Ingress Controller that this secret should be used.

- install NGINX Namespace: ``kubectl create namespace nginx-ingress``
- install NGINX Default Certificate: ``kubectl --namespace nginx-ingress create secret tls nginx-server-certs --key .k3d/navida.dev_private_key.key --cert .k3d/navida.dev_ssl_certificate.cer``
- install NGINX Ingress Controller: ``helm install nginx-ingress bitnami/nginx-ingress-controller --namespace nginx-ingress -f .k3d/ingress-values.yaml``

For the Ingress definition, it is important to include the ``ingressClassName``, otherwise complications may arise.
Wenn die Route nicht im root liegen soll, zb.: ``/api``, dann muss ``nginx.ingress.kubernetes.io/rewrite-target /$2`` gesetzt werden und die Route so ergänzt werden ``/api(/|$)(.*)``.
Danach werden Requests auf ``/api`` an den Service richtig weitergeleitet. Das sieht dann z.B so aus:

|Route am Ingress|Route am Service|
|---|---|
|``/api``|``/``|
|``/api/``|``/``|
|``/api/health``|``/health``|
|``/api/health/``|``/health``|

A simple test of the Ingress controller could look like this:

- create test namespace: ``kubectl create namespace test``
- create test deployment: ``kubectl create deployment nginx --image=nginx --namespace test``
- create test service: ``kubectl create service clusterip nginx --tcp=80:80 --namespace test``
- create test ingress: ``kubectl apply -f .k3d/nginx-ingress.yaml --namespace test``
