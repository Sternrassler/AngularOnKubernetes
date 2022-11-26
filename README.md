# Evaluation Angular on Kubernetes

In this project, we want to test whether Angular can run on Kubernetes.
For this purpose, an Angular project is created and built in a Docker container.
This container will then be deployed to Kubernetes and verified that the application and its routes work.

To create a Kubernetes cluster, K3D is used. A description of how to create the cluster can be found [here](.k3d/install.md).

## Angular project

The Angular project was created using Angular CLI. The application is a simple application with two routes to test its functionality in the Kubernetes cluster.

```sh
ng new AngularOnKubernetes
cd AngularOnKubernetes
ng generate component first
ng generate component second
```

app-routing.module.ts should look like this:

```ts
import { NgModule } from '@angular/core';
import { RouterModule, Routes } from '@angular/router';
import { FirstComponent } from './first/first.component';
import { SecondComponent } from './second/second.component';

const routes: Routes = [
  { path: 'first-component', component: FirstComponent },
  { path: 'second-component', component: SecondComponent },
];

@NgModule({
  imports: [RouterModule.forRoot(routes)],
  exports: [RouterModule]
})
export class AppRoutingModule { }
```

and app.component.html as follows:

```html
<h1>Angular Router App</h1>
<!-- This nav gives you links to click, which tells the router which route to use (defined in the routes constant in  AppRoutingModule) -->
<nav>
  <ul>
    <li><a routerLink="/first-component" routerLinkActive="active" ariaCurrentWhenActive="page">First Component</a></li>
    <li><a routerLink="/second-component" routerLinkActive="active" ariaCurrentWhenActive="page">Second Component</a></li>
  </ul>
</nav>
<!-- The routed views render in the <router-outlet>-->
<router-outlet></router-outlet>
```

That was it and is completely sufficient for our test.

## Docker Container

To build the Angular project in a Docker container, a Dockerfile is needed. This should look like the following:

```dockerfile
FROM node:19.1-alpine3.16 as build
WORKDIR /app

RUN npm install -g @angular/cli@15

COPY ./package.json .
RUN npm install

COPY . .
RUN ng build --configuration=production  --deploy-url=/testangular/ --base-href=/testangular/

# BASE IMAGE with an alias #
FROM nginx:1.23-alpine as runtime

# Copy contents from the other container with alias "build" #
# onto the specified path in the current container#
COPY --from=build /app/dist/angular-on-kubernetes /usr/share/nginx/html
COPY ./nginx.conf /etc/nginx/nginx.conf
```

the nginx.conf file should look like this:

```nginx
server {
    listen 80;
    listen [::]:80;
    server_name _;

    sendfile on;
    default_type application/octet-stream;

    gzip on;
    gzip_http_version 1.1;
    gzip_disable "MSIE [1-6]\.";
    gzip_min_length 256;
    gzip_vary on;
    gzip_proxied expired no-cache no-store private auth;
    gzip_types text/plain text/css application/json application/javascript application/x-javascript text/xml application/xml application/xml+rss text/javascript;
    gzip_comp_level 9;

    root /usr/share/nginx/html;
    index index.html;

    access_log /var/log/nginx/access.log main;
    error_log /var/log/nginx/error.log;

    location / {
        try_files $uri $uri/ /index.html;
    }
}
```

The Dockerfile is built using the command `docker build --rm -t sternrassler/angular-on-kubernetes:0.0.1 .`.

This uses the tag `sternrassler/angular-on-kubernetes:0.0.1`. This tag must also be used in the `kubernetes/deployment.yaml` file.

After that, the container can be tested locally with the command `docker run -d -p 8000:80 sternrassler/angular-on-kubernetes:0.0.1`.

## Deploy to Kubernetes

First, the container must be pushed to the Registry. This is done using the command `docker push sternrassler/angular-on-kubernetes:0.0.1`.

Now Namespace must be created in Kubernetes. This is done using the command `kubectl create namespace test`.

To deploy the container to Kubernetes, a deployment.yaml file is needed. This should look like the following:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: angular-on-kubernetes
  namespace: test
  labels:
    app: angular-on-kubernetes
spec:
  replicas: 1
  selector:
    matchLabels:
      app: angular-on-kubernetes
  template:
    metadata:
      labels:
        app: angular-on-kubernetes
    spec:
      containers:
        - name: angular-on-kubernetes
          image: sternrassler/angular-on-kubernetes:0.0.1
          imagePullPolicy: Always
          ports:
            - containerPort: 80
``` 

The deployment can be created using the command `kubectl apply -f kubernetes/deployment.yaml`.

To make the application accessible from the outside, a service.yaml and ingress.yaml file is needed. This should look like the following:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: angular-on-kubernetes
  namespace: test
spec:
  type: ClusterIP
  selector:
    app: angular-on-kubernetes
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
```

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: angular-on-kubernetes
  namespace: test
  annotations:
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
    nginx.ingress.kubernetes.io/rewrite-target: /$2
spec:
  ingressClassName: nginx
  rules:
    - host: local.navida.dev
      http:
        paths:
          - path: /testangular(/|$)(.*)
            pathType: Prefix
            backend:
              service:
                name: angular-on-kubernetes
                port:
                  number: 80
```

For simplicity, everything is packed into a `deploy.yaml`` here. And with the following command the whole thing is deployed to Kubernetes:

`kubectl apply -f kubernetes/deploy.yaml`

## Conclusion

Despite all claims of Angular, even in version 15, the DI provider APP_BASE_HREF does not work properly. It is not possible to host the application under a path other than the root path. This is a pity, because it is very important for the development of microfrontends that the application can be hosted under another path than the root path. The only way to host an application under a path other than the root path is to use ``--deploy-url=/testangular/ --base-href=/testangular/`` when building the application. However, this is not really nice since ``--deploy-url`` is set to depricated and should not really be used anymore.
