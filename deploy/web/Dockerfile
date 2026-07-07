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
#
# Die CalDAV-Server-Adresse ist NICHT im Image, sondern kommt zur Laufzeit aus
# der Umgebungsvariable CALDAV_HOST (nginx-Template via envsubst).
FROM nginx:alpine
COPY deploy/web/default.conf.template /etc/nginx/templates/default.conf.template
COPY build/web /usr/share/nginx/html
