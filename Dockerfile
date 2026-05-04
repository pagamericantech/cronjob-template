# Substitua este Dockerfile pelo build do seu app.
# Lembre-se: o nodepool critical ou noncritical utilizam arm64 (Graviton),
# então a imagem final precisa ser linux/arm64. O workflow já passa
# --platform=linux/arm64 — basta a base image suportar arm64.

FROM nginxinc/nginx-unprivileged:alpine

EXPOSE 8080
