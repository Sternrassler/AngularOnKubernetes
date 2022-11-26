FROM node:18-alpine3.16 as build
WORKDIR /app

RUN npm install -g @angular/cli@15

COPY ./package.json .
RUN npm install

COPY . .
RUN ng build --configuration=production


# BASE IMAGE with an alias #
FROM nginx:1.23-alpine as runtime

# Copy contents from the other container with alias "build" #
# onto the specified path in the current container#
COPY --from=build /app/dist/angular-on-kubernetes /usr/share/nginx/html
COPY ./nginx.conf /etc/nginx/conf.d/default.conf