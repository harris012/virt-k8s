set quiet
set shell := ['bash', '-euo', 'pipefail', '-c']
set script-interpreter := ['bash', '-euo', 'pipefail']

[private]
default:
    just talos -l

[doc('Apply Talos config to a node')]
[group('talos')]
apply-node ip mode='auto':
    talhelper gencommand apply --node "{{ ip }}" --extra-flags "--mode={{ mode }}" | bash

[doc('Download Talos machine image')]
[script]
download-image version:
    export SCHEMATIC="$(just talos schematic-id)"
    curl -fL --remove-on-error --retry 5 --retry-delay 5 --retry-all-errors --progress-bar \
        -o "{{ source_directory() }}/talos-{{ version }}-${SCHEMATIC:0:8}.iso" \
        "https://factory.talos.dev/image/${SCHEMATIC}/{{ version }}/metal-amd64.iso"
    just log info "Downloaded Talos" version "{{ version }}" schematic "${SCHEMATIC}"

[doc('Generate Talos configuration')]
[group('talos')]
generate-config:
    talhelper genconfig

[confirm("This will destroy your cluster and reset all nodes to maintenance mode — continue? [y/N]")]
[doc('Reset all nodes back to maintenance mode (DESTRUCTIVE)')]
[group('talos')]
reset:
    talhelper gencommand reset \
        --extra-flags="--reboot --system-labels-to-wipe STATE --system-labels-to-wipe EPHEMERAL --graceful=false --wait=false" | bash

[confirm("This will reset the specified node to maintenance mode — continue? [y/N]")]
[doc('Reset a single node back to maintenance mode (DESTRUCTIVE)')]
[group('talos')]
reset-node ip:
    talhelper gencommand reset --node "{{ ip }}" \
        --extra-flags="--reboot --system-labels-to-wipe STATE --system-labels-to-wipe EPHEMERAL --graceful=false --wait=false" | bash

[doc('Upgrade Kubernetes')]
[group('talos')]
upgrade-k8s:
    talhelper gencommand upgrade-k8s --extra-flags "--to '$(yq '.kubernetesVersion' talenv.yaml)'" | bash

[doc('Upgrade Talos on a single node')]
[group('talos')]
upgrade-node ip:
    talhelper gencommand upgrade --node "{{ ip }}" --extra-flags "--timeout=10m" | bash

[private]
schematic-id:
    curl -sX POST --data-binary @<(just template "{{ source_directory() }}/schematic.yaml.j2") "https://factory.talos.dev/schematics" | jq -r '.id'
