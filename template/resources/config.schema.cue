package config

import (
	"net"
	"list"
)

#Config: {
	network:    #Network
	kubernetes: #Kubernetes
	gateways:   #Gateways
	repository: #Repository
	cloudflare: #Cloudflare
	cilium:     #Cilium
	nodes: [...#Node]
	apps:      #apps

	spegel_enabled:     bool | *(len(nodes) > 1)
	cilium_bgp_enabled: cilium.bgp.router_addr != "" && cilium.bgp.router_asn != "" && cilium.bgp.node_asn != ""

	// Pairwise CIDR uniqueness. We can't use list.UniqueItems on these because
	// kubernetes.pod_cidr/svc_cidr are defaulted disjunctions (`*"…" | net.IPCIDR`),
	// and CUE evaluates the list constraint against the unresolved disjunction —
	// so the defaulted values silently slip through. Pairwise `!=` works.
	network: node_cidr: !=kubernetes.pod_cidr & !=kubernetes.svc_cidr
	kubernetes: pod_cidr: !=network.node_cidr & !=kubernetes.svc_cidr
	kubernetes: svc_cidr: !=network.node_cidr & !=kubernetes.pod_cidr

	_addrs_check: list.UniqueItems() & [
		kubernetes.api.addr, gateways.internal, gateways.dns, gateways.external,
	]

	_node_name_check: list.UniqueItems() & [for n in nodes {n.name}]
	_node_addr_check: list.UniqueItems() & [for n in nodes {n.address}]
	_node_mac_check:  list.UniqueItems() & [for n in nodes {n.mac_addr}]

	network: dns_servers: *["1.1.1.1", "1.0.0.1"] | _
	network: ntp_servers: *["162.159.200.1", "162.159.200.123"] | _
}

#Network: {
	// The network CIDR for the nodes.
	// e.g. "192.168.1.0/24"
	node_cidr: net.IPCIDR
	// DNS servers to use for the cluster (default: ["1.1.1.1", "1.0.0.1"]).
	dns_servers: [...net.IPv4]
	// NTP servers to use for the cluster (default: ["162.159.200.1", "162.159.200.123"]).
	ntp_servers: [...net.IPv4]
	// The default gateway for the nodes (defaults to the first IP in node_cidr).
	default_gateway?: net.IPv4 & !=""
	// VLAN tag for the Talos nodes (rare).
	vlan_tag?: string & !=""
}

#Kubernetes: {
	// The pod CIDR for the cluster, /16 recommended.
	pod_cidr: *"10.42.0.0/16" | net.IPCIDR
	// The service CIDR for the cluster, /16 recommended.
	svc_cidr: *"10.43.0.0/16" | net.IPCIDR
	api: {
		// The IP address of the Kube API.
		addr: net.IPv4
		// Additional SANs to add to the Kube API cert.
		tls_sans?: [...net.FQDN]
	}
}

#Gateways: {
	// Internal gateway load balancer IP.
	internal: net.IPv4
	// k8s_gateway DNS load balancer IP.
	dns: net.IPv4
	// External (cloudflared) gateway load balancer IP.
	external: net.IPv4
}

#Repository: {
	// GitHub repository, e.g. "harris012/virt-k8s".
	name: string
	// GitHub repository branch.
	branch: *"main" | string & !=""
	// Repository visibility.
	visibility: *"public" | "private"
}

#Cloudflare: {
	// Domain you wish to use from your Cloudflare account.
	domain: net.FQDN
	// API token with Zone:DNS:Edit and Account:Cloudflare Tunnel:Read permissions.
	token: string
}

#Cilium: {
	// The load balancer mode for cilium.
	loadbalancer_mode: *"dsr" | "snat"
	bgp: {
		// The IP address of the BGP router.
		router_addr: *"" | net.IPv4 & !=""
		// The BGP router ASN.
		router_asn: *"" | string & !=""
		// The BGP node ASN.
		node_asn: *"" | string & !=""
	}
}

#apps:	{
	// Tailscale Oauth client ID.
	client_id: string
	// Tailscale Oauth client secret.
	client_secret: string
	// Rook dashboard password.
	ROOK_DASHBOARD_PASSWORD: string
	// Kopia password.
	KOPIA_PASSWORD: string
	// Grafana admin password.
	GF_SECURITY_ADMIN_PASSWORD: string
	// OpenCloud admin password.
	OPEN_CLOUD_ADMIN_PASSWORD: string
	// MinIO root user.
	MINIO_ROOT_USER: string
	// MinIO root password.
	MINIO_ROOT_PASSWORD: string
	// n8n encryption key.
	N8N_ENCRYPTION_KEY: string
	// Postgres superuser name.
	POSTGRES_SUPER_USER: string
	// Postgres superuser password.
	POSTGRES_SUPER_PASS: string
	// Initial Postgres database name.
	INIT_POSTGRES_DBNAME: string
	// Initial Postgres host.
	INIT_POSTGRES_HOST: string
	// JWT secret for internal services.
	JWT_SECRET: string
	// Initial Postgres user flags (e.g. "CREATEDB").
	INIT_POSTGRES_USER_FLAGS: string
	// Admin token for custom applications.
	ADMIN_TOKEN: string
	// SMTP server host.
	SMTP_HOST: string
	// SMTP from address.
	SMTP_FR: string
	// SMTP username.
	SMTP_USERNAME: string
	// SMTP password.
	SMTP_PASSWORD: string
	// Initial Nextcloud database name.
	INIT_POSTGRES_DBNAME_NEXTCLOUD: string
	// Initial Nextcloud Postgres host.
	INIT_POSTGRES_HOST_NEXTCLOUD: string
	NEXTCLOUD_USERNAME: string
	NEXTCLOUD_PASSWORD: string
	TIMEZONE: string
	COLLABORA_USERNAME: string
	COLLABORA_PASSWORD: string
	WHITEBOARD_JWT_SECRET_KEY: string
	NEXTLOUD_WHITEBOARD_SECRET: string
	SMTP_FROM: string
	SMTP_FR: string
	MAIL_DOMAIN: string
	WIREGUARD_PRIVATE_KEY: string
	WIREGUARD_ADDRESSES: string
	GARAGE_RPC_SECRET: string
	GARAGE_ADMIN_TOKEN: string
	GARAGE_METRICS_TOKEN: string
	CNPG_BUCKET_KEY: string
	CNPG_BUCKET_SEC: string
	ACCESS_KEY_ID: string
}

#Node: {
	// Name of the node (must match [a-z0-9-]+).
	name: =~"^[a-z0-9][a-z0-9\\-]{0,61}[a-z0-9]$|^[a-z0-9]$" & !="global" & !="controller" & !="worker"
	// IP address of the node (must be in network.node_cidr).
	address: net.IPv4
	// Set to true if this is a controller node.
	controller: bool
	// Device path or serial number of the disk.
	disk: string
	// MAC address of the NIC.
	mac_addr: =~"^([0-9a-f]{2}[:]){5}([0-9a-f]{2})$"
	// Schematic ID from https://factory.talos.dev/.
	schematic_id: =~"^[a-z0-9]{64}$"
	// MTU for the NIC.
	mtu?: >=1450 & <=9000
	// SecureBoot mode.
	secureboot?: bool
	// TPM-based disk encryption.
	encrypt_disk?: bool
	// Kernel modules required by schematic_id extensions.
	kernel_modules?: [...string]
}

#Config
