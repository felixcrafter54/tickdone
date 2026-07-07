# Tickdone als Web/PWA ausliefern

Ziel: Die Flutter-Web-App im Browser nutzbar machen. Das einzige echte Problem
ist **CORS** – der CalDAV-Server `cloud.app-noster.de` sendet keine CORS-Header
und ist nicht änderbar. Lösung: **Same-Origin-Reverse-Proxy**. Die Web-App
spricht CalDAV nicht direkt an, sondern über `/caldav/` auf der **eigenen**
Domain. Aus Browsersicht ist das same-origin → CORS entfällt komplett.

Die App macht das automatisch: im Web-Build ist die CalDAV-Basis fest
`https://<eure-domain>/caldav/` (siehe `webCaldavPfad` in
`lib/services/caldav_service.dart`), keine Discovery, kein Server-Feld im Login.
Android/Desktop bleiben unverändert beim direkten Server.

## Aufbau (Variante B)

```
Browser ── HTTPS ──▶ Nginx Proxy Manager ──▶ [tickdone-web]
                     (SSL + Forward)           ├── /            → Flutter-Web
                                               └── /caldav/     → cloud.app-noster.de/caldav/
```

Der `tickdone-web`-Container (dieses Verzeichnis) liefert die App **und** proxyt
CalDAV. Der bereits laufende NPM bleibt „dumm": nur SSL + Forward auf diesen
Container.

## Zwei Wege

Das Docker-Image enthält **kein** Flutter – der Web-Build wird vorher erzeugt und
nur in ein schlankes nginx kopiert (kein GB-großes SDK-Image, kein Dart-Versions-
Ärger, Build in Sekunden). Dasselbe Dockerfile läuft lokal wie in der CI.

### Weg 1 (empfohlen): fertiges Image aus GHCR ziehen
Die GitHub-Actions-CI baut bei jedem Push auf `main` das Image und pusht es nach
`ghcr.io/felixcrafter54/tickdone-web:latest`. Der Server braucht **weder Flutter
noch den Quellcode** – nur Docker + `docker-compose.yml`:

```bash
docker compose -f deploy/web/docker-compose.yml pull
docker compose -f deploy/web/docker-compose.yml up -d
```

Einmalig, damit der Server ohne Login ziehen kann: das Package auf GitHub unter
**Repo → Packages → tickdone-web → Package settings → Change visibility →
Public** stellen. (Bleibt es privat: auf dem Server `docker login ghcr.io` mit
einem Personal Access Token mit `read:packages`.)

Update später: neuer Push auf `main` → CI baut → am Server `pull` + `up -d`.

### Weg 2: lokal selbst bauen (ohne CI/Registry)
Auf einem Rechner mit Flutter:
```bash
flutter build web --release        # erzeugt build/web (~40 MB, nicht in git)
docker compose -f deploy/web/docker-compose.yml up --build
```
> Flutter auf einem anderen Rechner als Docker (z.B. Windows/Linux)? `build/web`
> einfach in den Projektordner auf dem Docker-Host kopieren (nach `build/web`).

## In NPM einhängen (Variante B) und aufrufen

- **NPM:** Proxy Host `tickdone.<eure-domain>` anlegen; Forward Hostname/IP
  `tickdone-web`, Port `80` (Container im gemeinsamen Docker-Netz – dazu in der
  `docker-compose.yml` das NPM-Netz aktivieren); SSL-Zertifikat wie gewohnt.
- **Aufrufen:** `https://tickdone.<eure-domain>` → Login mit Benutzer/Passwort
  (kein Server-Feld nötig).

## Wichtig / Fallstricke

- **Nur HTTPS.** Der Proxy sieht die Basic-Auth-Zugangsdaten im Header – bei
  eigenem Server ok, aber niemals über HTTP.
- **`proxy_pass` fest auf den einen CalDAV-Host** (kein offener Proxy).
- **Host-Header + SNI** müssen gesetzt sein (`proxy_ssl_server_name on`), sonst
  antwortet der Zielserver falsch. **End-Slash bei `/caldav/` beibehalten.**
- **href-Auflösung:** Der Proxy-Pfad ist bewusst `/caldav/` (identisch zum
  Zielserver). Liefert der Server absolute **Pfad**-hrefs (`/caldav/...`), bleiben
  sie same-origin. Liefert er dagegen **volle URLs**
  (`https://cloud.app-noster.de/caldav/...`), müssten diese umgeschrieben werden
  (nginx `sub_filter`/`proxy_redirect`). → Beim ersten Login in den Browser-
  Netzwerk-Tab schauen: gehen alle CalDAV-Requests an die eigene Domain? Falls
  nicht, hier nachbessern.

## Lokal testen (nur Dev, nicht Prod)

Ohne Proxy scheitert CalDAV an CORS. Für schnelle UI-Tests:
```bash
flutter run -d chrome --web-browser-flag "--disable-web-security"
```
Für einen echten End-to-End-Test den Container bauen und über die Domain testen.
