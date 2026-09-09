FROM nginx:alpine
COPY platform-services/games/lyback-static/ /usr/share/nginx/html/
COPY platform-services/games/nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
