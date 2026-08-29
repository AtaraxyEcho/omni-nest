FROM node:20-alpine
WORKDIR /app
RUN npm init -y && npm install NeteaseCloudMusicApi@4.32.0
EXPOSE 3000
CMD ["node", "-e", "require('./node_modules/NeteaseCloudMusicApi').serveNcmApi({port: 3000})"]
