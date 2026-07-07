# Schlankes Image: nur nginx + fertige Flutter-Web-Dateien. KEIN Flutter im
# Docker-Build (kein GB-großes SDK-Image, keine Dart-Versions-Konflikte).
#
# Voraussetzung: vorher einmal den Web-Build erzeugen (auf einem Rechner mit
# Flutter), sodass build/web existiert:
#
#   flutter build web --release
#   docker build -f deploy/web/Dockerfile -t tickdone-web .
#
# build/web kann auch auf einem anderen Rechner gebaut und hierher kopiert
# werden (build/web ist absichtlich nicht in git – reines Artefakt).
FROM nginx:alpine
COPY deploy/web/nginx.conf /etc/nginx/conf.d/default.conf
COPY build/web /usr/share/nginx/html
