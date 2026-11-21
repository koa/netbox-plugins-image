# syntax=docker/dockerfile:1
#
# NetBox-Community-Image + Plugins.
# Den Tag unten hält Renovate automatisch auf dem neuesten NetBox-Release.
FROM ghcr.io/netbox-community/netbox:v4.5.9

# Plugins installieren (nur wenn plugin_requirements.txt echte Einträge enthält)
COPY plugin_requirements.txt /opt/netbox/plugin_requirements.txt
RUN if grep -qvE '^[[:space:]]*(#|$)' /opt/netbox/plugin_requirements.txt; then \
      /usr/local/bin/uv pip install -r /opt/netbox/plugin_requirements.txt; \
    else \
      echo "Keine Plugins in plugin_requirements.txt – überspringe Installation"; \
    fi

# Statische Dateien der Plugins einsammeln.
# plugins.py wird nur dafür gebraucht und danach wieder entfernt –
# im Cluster setzt der Helm-Chart PLUGINS / PLUGINS_CONFIG.
COPY configuration/plugins.py /etc/netbox/config/plugins.py
RUN DEBUG="true" SECRET_KEY="dummydummydummydummydummydummydummydummydummydummy" \
      /opt/netbox/venv/bin/python /opt/netbox/netbox/manage.py collectstatic --no-input \
 && rm /etc/netbox/config/plugins.py
