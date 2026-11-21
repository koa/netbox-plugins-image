# NetBox-Image mit Plugins

Baut das offizielle NetBox-Community-Image plus Plugins und veröffentlicht es auf
`ghcr.io/<owner>/netbox-plugins`. Neue NetBox- und Plugin-Releases kommen vollautomatisch:

```
neues NetBox-/Plugin-Release
        │
        ▼
Renovate öffnet PR "NetBox und Plugins"  ──►  CI baut + Smoke-Test
        │                                         │
        │                  rot (z.B. Plugin noch nicht kompatibel):
        │                  PR bleibt offen, bis Renovate passende
        │                  Plugin-Version in denselben PR nachzieht
        ▼ grün
Auto-Merge (Patch/Minor)  ──►  Build auf main  ──►  Push nach ghcr.io
                                                       │
                                                       ▼
                                  Renovate im Helm-Repo hebt den Image-Tag an
```

Major-Updates (NetBox 4 → 5) werden **nicht** automatisch gemergt.
Zusätzlich wird jeden Montag neu gebaut, damit Security-Fixes im Basis-Image ankommen.

## Dateien

| Datei | Zweck |
|---|---|
| `Dockerfile` | Basis-Image (Version von Renovate gepflegt), installiert Plugins, `collectstatic` |
| `plugin_requirements.txt` | Plugins mit pip-Namen und exakter Version |
| `configuration/plugins.py` | Modulnamen der Plugins – nur für Build und Smoke-Test |
| `.github/workflows/build.yml` | Build, Smoke-Test (`manage.py check`), Multi-Arch-Push |
| `renovate.json` | Automatische Updates inkl. Auto-Merge |

## Einrichtung (einmalig)

1. Repo auf GitHub anlegen und diesen Inhalt pushen.
2. **Renovate-App installieren**: <https://github.com/apps/renovate> → nur für dieses Repo (und das Helm-Repo) freigeben.
3. **Auto-Merge erlauben**: *Settings → General → Allow auto-merge* aktivieren.
4. **Branch-Schutz für `main`**: *Settings → Branches → Add rule* → „Require status checks to pass“ → Check `build` auswählen.
   Ohne diesen Schritt würde GitHub auch rote PRs mergen.
5. Nach dem ersten erfolgreichen Build: *Packages → netbox-plugins → Package settings*
   → entweder **Public** stellen oder im Cluster ein `imagePullSecret` anlegen.

Renovate öffnet zuerst einen „Configure Renovate“-PR und danach sofort einen PR auf den
neuesten NetBox-Release.

## Plugin hinzufügen

1. `plugin_requirements.txt`: `netbox-bgp==0.x.y` (Version laut Kompatibilitätsmatrix des Plugins)
2. `configuration/plugins.py`: `"netbox_bgp"` in `PLUGINS` aufnehmen
3. Helm-Values: Plugin in `plugins` (und ggf. `pluginsConfig`) eintragen
4. PR öffnen → CI testet → mergen

## Image-Tags

| Tag | Beispiel | Verwendung |
|---|---|---|
| `<netbox>-<datum>-<sha>` | `v4.5.9-20261123-a1b2c3d` | **im Helm-Chart verwenden** (unveränderlich) |
| `<netbox>` | `v4.5.9` | zeigt immer auf den letzten Build dieser Version |
| `latest` | | letzter Build auf `main` |

## Helm-Values

```yaml
netbox:            # Name/Alias der Dependency in deiner Chart.yaml
  image:
    registry: ghcr.io
    repository: <owner>/netbox-plugins
    tag: v4.5.9-20261123-a1b2c3d
    # pullSecrets: [ghcr-pull]   # falls das Package privat ist

  plugins:
    - netbox_bgp
  pluginsConfig:
    netbox_bgp:
      device_ext_page: right
```

## Automatische Updates im Helm-Repo

Damit auch das Deployment automatisch den neuen Image-Tag (und neue Chart-Versionen) bekommt,
im **Helm-Repo** diese `renovate.json` ablegen:

```json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": ["config:recommended"],
  "packageRules": [
    {
      "description": "Eigenes NetBox-Image: Tags vX.Y.Z-YYYYMMDD-sha",
      "matchDatasources": ["docker"],
      "matchPackageNames": ["ghcr.io/<owner>/netbox-plugins"],
      "versioning": "regex:^v(?<major>\\d+)\\.(?<minor>\\d+)\\.(?<patch>\\d+)-(?<build>\\d{8})-[0-9a-f]+$",
      "groupName": "NetBox",
      "automerge": true,
      "matchUpdateTypes": ["patch", "minor"]
    },
    {
      "description": "NetBox-Helm-Chart (OCI-Dependency in Chart.yaml)",
      "matchManagers": ["helmv3"],
      "matchPackageNames": ["netbox"],
      "groupName": "NetBox"
    }
  ]
}
```

Renovate erkennt `image.registry/repository/tag` in `values.yaml` und die
`oci://ghcr.io/netbox-community/netbox-chart`-Dependency in `Chart.yaml` automatisch.
Ob dort ebenfalls automatisch gemergt (und per Argo CD/Flux ausgerollt) werden soll, ist eine
Abwägung – NetBox führt beim Start Datenbank-Migrationen aus, ein Backup vorher ist sinnvoll.

> Ist das Package privat, braucht Renovate im Helm-Repo Lesezugriff darauf
> (Package settings → *Manage Actions access* bzw. ein `hostRules`-Token).
