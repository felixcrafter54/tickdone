# Tickdone als Web/PWA ausliefern

Ziel: Die Flutter-Web-App im Browser nutzbar machen. Das einzige echte Problem
ist **CORS** – der CalDAV-Server `cloud.app-noster.de` sendet keine CORS-Header
und ist nicht änderbar. Lösung: **Same-Origin-Reverse-Proxy**. Die Web-App
spricht CalDAV nicht direkt an, sondern über `/caldav/` auf der **eigenen**
Domain. Aus Browsersicht ist das same-origin → CORS entfällt komplett.

Die App macht das automatisch: im Web-Build ist die CalDAV-Basis die eigene
Domain; der nginx reicht die **RFC-6764-Discovery** (`.well-known`) UND alle
**WebDAV-Methoden** an den echten Server durch. Damit funktioniert ein
**beliebiger** CalDAV-Server/Basispfad (Nextcloud `/remote.php/dav`, Radicale
`/`, ownCloud/OpenCloud, Baikal ...) – nicht mehr nur ein fest verdrahtetes
`/caldav/`. Kein Server-Feld im Login; angezeigt wird „Verbunden mit ...".
Android/Desktop bleiben unverändert beim direkten Server.

## Aufbau (Variante B)

```
Browser ── HTTPS ──▶ Nginx Proxy Manager ──▶ [tickdone-web]
                     (SSL + Forward)           ├── /            → Flutter-Web
                                               └── .well-known + WebDAV-Methoden → <CALDAV_HOST>
```

Der `tickdone-web`-Container (dieses Verzeichnis) liefert die App **und** proxyt
CalDAV. Der bereits laufende NPM bleibt „dumm": nur SSL + Forward auf diesen
Container.

## Zwei Wege

Das Docker-Image enthält **kein** Flutter – der Web-Build wird vorher erzeugt und
nur in ein schlankes nginx kopiert (kein GB-großes SDK-Image, kein Dart-Versions-
Ärger, Build in Sekunden). Dasselbe Dockerfile läuft lokal wie in der CI.

Die **CalDAV-Server-Adresse steckt NICHT im Image/Repo**, sondern kommt zur
Laufzeit aus der Umgebungsvariable **`CALDAV_HOST`**. Die darf tolerant
eingetragen werden – so, wie der Dienst sie ausgibt (mit/ohne Schema, mit/ohne
Pfad, mit/ohne End-Slash); für den Proxy wird daraus automatisch der blanke
Host abgeleitet. So bleibt sie aus dem public Repo heraus.

### Weg 1 (empfohlen): fertiges Image aus GHCR ziehen
Die GitHub-Actions-CI baut bei jedem Push auf `main` das Image und pusht es nach
`ghcr.io/felixcrafter54/tickdone-web:latest`. Der Server braucht **weder Flutter
noch den Quellcode** – nur Docker + `docker-compose.yml` + eine `.env`:

```bash
# einmalig: Server-Adresse setzen (Datei ist per .gitignore ausgeschlossen)
cp deploy/web/.env.example deploy/web/.env
#   -> deploy/web/.env editieren: CALDAV_HOST=dein.server.de

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
  antwortet der Zielserver falsch.
- **Routing:** GET/HEAD/POST liefern die SPA; alle übrigen (WebDAV-)Methoden und
  `/.well-known/` gehen an den echten Server – am gleichen Pfad. So bleiben die
  Basispfade beliebig (Discovery findet den richtigen).
- **href-Auflösung (wichtigster Fallstrick):** Liefert der Server absolute
  **Pfad**-hrefs/Redirects (`/caldav/...`, `/remote.php/dav/...`), bleiben sie
  same-origin und alles funktioniert. Liefert er dagegen **volle URLs** mit
  eigenem Host (`https://<dein-server>/...`), zeigt die App zwar „Verbunden mit",
  die Requests gingen aber cross-origin ins Leere → dann in nginx umschreiben
  (`sub_filter`). Beim ersten Login in den Browser-Netzwerk-Tab schauen: gehen
  alle CalDAV-Requests an die eigene Domain?

## Lokal testen (localhost, ohne NPM)

Schnelltest mit dem GHCR-Image und einem `docker run` (Server-Host per `-e`):
```bash
docker run -d --name tickdone-web -p 8085:80 \
  -e CALDAV_HOST=dein.server.de \
  ghcr.io/felixcrafter54/tickdone-web:latest
# -> http://localhost:8085
```

Nur reine UI (ohne Proxy/CalDAV): `flutter run -d chrome`. Ein echter
End-to-End-Test läuft über den Container (oben) bzw. hinter NPM über die Domain.
