# Baut den Flutter-Web-Build und liefert ihn mit dem CalDAV-Proxy-nginx aus.
# Selbstständig – ein `docker build` erledigt alles (Build-Kontext = Repo-Wurzel).
#
#   docker build -f deploy/web/Dockerfile -t tickdone-web .
#
# Alternative ohne Flutter-Image: vorher `flutter build web --release` und die
# Build-Stufe durch ein `COPY build/web /usr/share/nginx/html` ersetzen.

# Feste Flutter-Version (= lokale Entwicklungsversion). NICHT ":stable"
# nehmen – dessen Dart kann hinter dem in pubspec geforderten SDK liegen
# ("Because tickdone requires SDK version ^3.12.2, version solving failed").
FROM ghcr.io/cirruslabs/flutter:3.44.4 AS build
WORKDIR /app
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get
COPY . .
RUN flutter build web --release

FROM nginx:alpine
COPY deploy/web/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/build/web /usr/share/nginx/html
