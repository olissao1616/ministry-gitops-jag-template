FROM node:lts-alpine as build

WORKDIR /app

# Copy the package.json and install dependencies
COPY package*.json ./
RUN npm install --force

# Copy rest of the files
COPY . .

# Build the project
RUN npm run build

FROM nginx:alpine as run

RUN apk add nodejs-current npm supervisor
RUN mkdir -p /var/log/supervisor  
RUN mkdir -p /etc/supervisor/conf.d

## Remove default nginx index page
RUN rm -rf /opt/app-root/src/*
RUN chmod g+rwx /var/cache/nginx /var/run /var/log/nginx /var/log/supervisor

# Copy from the stage 1 build result
COPY --from=build /app/.next/standalone /opt/app-root/src/lea
COPY --from=build /app/.next/static /opt/app-root/src/lea/.next/static
COPY --from=build /app/.next/cache /opt/app-root/src/lea/.next/cache
COPY --from=build /app/.next/types /opt/app-root/src/lea/.next/types
COPY --from=build /app/public /opt/app-root/src/lea/public

COPY --from=build /app/nginx.conf /etc/nginx/nginx.conf
COPY --from=build /app/supervisor.conf /etc/supervisor/conf.d/supervisor.conf

# Update server.js to set const hostname = '0.0.0.0'
RUN sed -i 's/process.env.HOSTNAME ||//' /opt/app-root/src/lea/server.js

# need to expose two ports (8000 for ngnix; 3000 for nextjs)
EXPOSE 8000 3000

# run supervisor
CMD  supervisord -c /etc/supervisor/conf.d/supervisor.conf
