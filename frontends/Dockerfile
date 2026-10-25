# Dockerfile para servir os 7 front-ends estáticos compilados via Nginx Alpine (SW-08)
FROM nginx:1.26-alpine

# Criação de usuário não-root (SW-01, R12)
RUN touch /var/run/nginx.pid && \
    chown -R nginx:nginx /var/run/nginx.pid /var/cache/nginx /var/log/nginx /etc/nginx/conf.d

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY apps/ /usr/share/nginx/html/

USER nginx

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
