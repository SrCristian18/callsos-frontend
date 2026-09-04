# --- Fase 1: Construcción de Flutter ---
FROM debian:stable-slim AS build

# Instalar dependencias necesarias para Flutter
RUN apt-get update && apt-get install -y curl git unzip xz-utils zip libglu1-mesa && rm -rf /var/lib/apt/lists/*

# Descargar Flutter SDK
RUN git clone https://github.com/flutter/flutter.git -b stable /flutter
ENV PATH="/flutter/bin:/flutter/bin/cache/dart-sdk/bin:${PATH}"

WORKDIR /app

# Copiar configuración de dependencias para aprovechar la caché
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

# Copiar el resto del código y compilar para Web (o la plataforma que auditen)
COPY . .

# Modo prueba Activado (Simulacion)
# MODO_PRUEBA_HABILITADO es un flag de COMPILACIÓN, no de runtime: Flutter
# Web lo "hornea" dentro del JS compilado vía --dart-define. Por eso no
# basta con cambiarlo en el .env y hacer restart — hay que reconstruir la
# imagen (docker compose build) para que tenga efecto. Ver docker-compose.yml
# (build.args) y .env (MODO_PRUEBA_HABILITADO).
ARG MODO_PRUEBA_HABILITADO=false
RUN flutter build web --release \
    --dart-define=MODO_PRUEBA_HABILITADO=${MODO_PRUEBA_HABILITADO}

# Estado normal
# RUN flutter build web --release

#Se puede usar en caso que se requiera
# Ejemplo de cómo cambiaría la línea de compilación en tu Dockerfile si lo requieren más adelante
# RUN flutter build web --release --dart-define=BASE_URL=http://localhost:8080

# --- Fase 2: Servidor Web ---
FROM nginx:alpine
# Copiar el build de Flutter al directorio por defecto de Nginx
COPY --from=build /app/build/web /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]