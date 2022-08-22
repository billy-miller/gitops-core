package greymatter

import (
	corev1 "k8s.io/api/core/v1"
	"github.com/greymatter-io/common/api/meshv1"
)

config: {
	// Flags
	spire:                     bool | *false @tag(spire,type=bool)           // enable Spire-based mTLS
	auto_apply_mesh:           bool | *true  @tag(auto_apply_mesh,type=bool) // apply the default mesh specified above after a delay
	openshift:                 bool | *false @tag(openshift,type=bool)
	enable_historical_metrics: bool | *true  @tag(enable_historical_metrics,type=bool)
	debug:                     bool | *false @tag(debug,type=bool) // currently just controls k8s/outputs/operator.cue for debugging
	test:                      bool | *false @tag(test,type=bool)  // currently just turns off GitOps so CI integration tests can manipulate directly

	// for a hypothetical future where we want to mount specific certificates for operator webhooks, etc.
	generate_webhook_certs: bool | *true        @tag(generate_webhook_certs,type=bool)
	cluster_ingress_name:   string | *"cluster" // For OpenShift deployments, this is used to look up the configured ingress domain
}

mesh: meshv1.#Mesh & {
	metadata: {
		name: string | *"greymatter-mesh"
	}
	spec: {
		install_namespace: string | *"greymatter"
		watch_namespaces:  [...string] | *["default", "plus", "examples", "robot-shop"]
		release_version:   string | *"1.7" // deprecated
		zone:              string | *"default-zone"
		images: {
			proxy:       string | *"quay.io/greymatterio/gm-proxy:1.7.0"
			catalog:     string | *"quay.io/greymatterio/gm-catalog:3.0.5"
			dashboard:   string | *"quay.io/greymatterio/gm-dashboard:connections"
			control:     string | *"quay.io/greymatterio/gm-control:1.7.3"
			control_api: string | *"quay.io/greymatterio/gm-control-api:1.7.3"
			redis:       string | *"redis:latest"
			prometheus:  string | *"prom/prometheus:v2.36.2"
		}
	}
}

defaults: {
	image_pull_secret_name: string | *"gm-docker-secret"
	image_pull_policy:      corev1.#enumPullPolicy | *corev1.#PullAlways
	xds_host:               "controlensemble.\(mesh.spec.install_namespace).svc.cluster.local"
	redis_cluster_name:     "redis"
	redis_host:             "\(redis_cluster_name).\(mesh.spec.install_namespace).svc.cluster.local"
	spire_selinux_context:  string | *"s0:c30,c5"
	sidecar_list:           [...string] | *["dashboard", "catalog", "controlensemble", "edge"]

	ports: {
		default_ingress: 10808
		edge_ingress:    defaults.ports.default_ingress
		redis_ingress:   10910
		metrics:         8081
	}

	images: {
		operator: string | *"quay.io/greymatterio/operator:0.9.2" @tag(operator_image)
	}

	edge: {
		key:        "edge"
		enable_tls: false
oidc: {
   endpoint_host: "iam2.greymatter.io"
   endpoint_port:  1234
   endpoint:          "http://ad94522d6c54147459938792f6b58971-1296074563.us-east-1.elb.amazonaws.com"
   domain:            ""
   client_id:           "example1"
   client_secret:    "dtTDcMoW0mc88i3VJQnYVzOsWPU9hJr9"
   realm:         "example-realm"
   jwt_authn_provider: {
       keycloak: {
           issuer: "\(endpoint)/realms/\(realm)"
           audiences: ["\(client_id)"]
           remote_jwks: {
               http_uri: {
                   uri:     "\(endpoint)/realms/\(realm)/protocol/openid-connect/certs"
                   cluster: "edge_to_keycloak"
               }
           }
       }
   }
}

