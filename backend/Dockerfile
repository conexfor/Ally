# Construir desde la raíz del repositorio:
#   docker build -f backend/Dockerfile -t ally-api .
FROM dart:stable AS build
WORKDIR /src
COPY packages/ally_core/pubspec.* packages/ally_core/
COPY backend/pubspec.* backend/
RUN cd backend && dart pub get
COPY packages/ally_core packages/ally_core
COPY backend backend
RUN cd backend && dart pub get --offline && dart compile exe bin/server.dart -o /out/server

FROM scratch
COPY --from=build /runtime/ /
COPY --from=build /out/server /app/server
COPY backend/migrations /app/migrations
WORKDIR /app
EXPOSE 8080
CMD ["/app/server"]
