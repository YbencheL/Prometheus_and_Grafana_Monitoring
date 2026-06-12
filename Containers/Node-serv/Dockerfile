FROM node:26-bookworm

WORKDIR /app

COPY ./files/* ./

RUN apt update && apt install -y curl

RUN npm ci --omit=dev

EXPOSE 8000

CMD ["node", "server.js"]