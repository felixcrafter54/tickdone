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
# Leitet aus CALDAV_HOST den blanken Proxy-Host ab und schreibt /app-config.json
# (wird als .envsh vom nginx-Entrypoint vor der envsubst-Ersetzung gesourced).
# WICHTIG: Der Entrypoint sourct .envsh nur, wenn die Datei ausführbar ist –
# das +x-Bit geht beim COPY aus Windows/CI sonst verloren.
COPY deploy/web/docker-entrypoint.d/15-tickdone.envsh /docker-entrypoint.d/15-tickdone.envsh
RUN chmod +x /docker-entrypoint.d/15-tickdone.envsh
COPY build/web /usr/share/nginx/html
