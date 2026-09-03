# Sync Manager Git v2

Windows-/PowerShell-Werkzeug fuer GitHub-Projekte mit Standardbasis `C:\Projekte`.

## v2

- GitHub Repo Picker mit Suche und Filter
- Clone nach `C:\Projekte`
- Sync: Commit -> Pull/Rebase -> Push
- Lokalen Projektordner direkt als neues GitHub-Repo pushen
- Neues Repo wird bei Bedarf automatisch **privat** angelegt
- Git-Ausgabe laeuft sichtbar in einem separaten PowerShell-Fenster
- GUI bleibt waehrend Git-Operationen bedienbar
- Standard-`.gitignore` fuer IDE-, Build-, Temp- und Secret-Dateien
- GitHub-PAT wird per Windows DPAPI gespeichert
- PAT wird **nicht mehr in `.git/config` oder der Remote-URL gespeichert**

## Einmaliges Setup

```powershell
.\gh-setup.ps1
```

Standardkonfiguration:

- GitHub User: `jackaloissteam-cloud`
- Projektbasis: `C:\Projekte`
- Token: `%USERPROFILE%\.gh_tools\token.dat` (Windows DPAPI)

## GUI

```powershell
.\gh-pick.ps1
```

oder:

```text
gh-pick.bat
```

## Lokalen Ordner nach GitHub pushen

```powershell
.\gh-push.ps1 -Path "C:\Projekte\Mein-Projekt"
```

## Vorhandenes lokales Repo synchronisieren

```powershell
.\gh-sync.ps1 -Path "C:\Projekte\Mein-Projekt"
```

## Repo von GitHub importieren

```powershell
.\gh-import.ps1 -Repo "Mein-Repo"
```

## Sicherheit

Der gespeicherte PAT wird fuer Git-Authentifizierung nur kurzfristig ueber `GIT_ASKPASS`
an Git uebergeben. Das normale `origin` bleibt eine saubere URL wie:

```text
https://github.com/jackaloissteam-cloud/Mein-Projekt.git
```

Keine Token in Commits, Remote-URLs oder `.git/config`.