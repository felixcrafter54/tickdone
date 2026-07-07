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

## Schritte

Das Docker-Image enthält **kein** Flutter – der Web-Build wird vorher mit deinem
vorhandenen Flutter erzeugt und dann nur in ein schlankes nginx kopiert (kein
GB-großes SDK-Image, kein Dart-Versions-Ärger, Build in Sekunden).

1. **Web-Build erzeugen** (auf einem Rechner mit Flutter):
   ```bash
   flutter build web --release
   ```
   Ergebnis liegt in `build/web` (ca. 40 MB, nicht in git).

   > Baust du auf einem anderen Rechner als dem Docker-Host (z.B. Flutter auf
   > Windows, Docker auf Linux)? Dann `build/web` einfach in den Projektordner
   > auf dem Docker-Host kopieren (nach `build/web`).

2. **Image bauen** (Repo-Wurzel als Kontext, `build/web` muss existieren):
   ```bash
   docker build -f deploy/web/Dockerfile -t tickdone-web .
   ```
   oder per Compose: `docker compose -f deploy/web/docker-compose.yml up -d --build`

3. **In NPM einhängen** (Variante B):
   - Proxy Host `tickdone.<eure-domain>` anlegen.
   - Forward Hostname/IP: `tickdone-web`, Port `80` (Container im gemeinsamen
     Docker-Netz – dazu in der `docker-compose.yml` das NPM-Netz aktivieren).
   - SSL-Zertifikat wie gewohnt in NPM.

4. **Aufrufen**: `https://tickdone.<eure-domain>` → Login mit Benutzer/Passwort
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
