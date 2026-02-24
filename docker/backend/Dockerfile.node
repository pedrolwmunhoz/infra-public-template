# Node.js backend (Express/Fastify/etc.)
FROM node:20-alpine AS builder
WORKDIR /app

COPY package.json package-lock.json* ./
RUN npm ci

COPY . .

# Ajuste o script para o comando que sobe a API (ex.: npm run start)
CMD ["npm", "run", "start"]
