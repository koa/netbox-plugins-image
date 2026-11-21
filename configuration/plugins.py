# Wird NUR beim Image-Build (collectstatic) und im CI-Smoke-Test verwendet.
# Im Kubernetes-Cluster steuern die Helm-Values `plugins` und `pluginsConfig`.
#
# Hier die Modulnamen aller Plugins aus plugin_requirements.txt eintragen.
PLUGINS = [
    # "netbox_bgp",
    # "netbox_topology_views",
    "netbox_dns"
]
