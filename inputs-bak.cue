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
		watch_namespaces:  [...string] | *["default", "plus", "examples"]
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
           endpoint_host: "iam.greymatter.io"
           endpoint_port: 443
           endpoint:      "https://\(endpoint_host)"
           domain:        "ad94522d6c54147459938792f6b58971-1296074563.us-east-1.elb.amazonaws.com"
           client_id:     "example1"
           client_secret: "yJsMB9g4lZBx2Lfs5I7heP4jbRlNYLYE"
           realm:         "example-realm"
           jwt_authn_provider: {
               keycloak: {
                   issuer: "\(endpoint)/auth/realms/\(realm)"
                   audiences: ["example1"]
                   local_jwks: {
                       inline_string: #"""
                          {"keys":[{"kid":"43CtqsfMa6XtbFIslGLrrjUHNhbV50ivgPgQOPtNwDA","kty":"RSA","alg":"RSA-OAEP","use":"enc","n":"8oQYv6bfsBxDer32H6t_Ywzq89a3qooPdSM--PLESyOXzP_zVtDNzrzQPGsRZ6KE4-vTVNgSkqL_2O2uItpRMqc1GwBBd7iqACLhd3IKlGnwS-loAYi9rXKZps-rBguA5TAWq3IL9BQo4gHg0v6jODv3acuQHiW3UvbK6SRTVIWIePrOq4NlfHDfi2hgRpgD7GCiNxjcZxxpXkRnFaKnVU9WGHs3gWnAFSev6dvxzyppMutwKW2ROCl0OTjWqBAPHBwREgxaanTVKRmELMEznYWE9OeZVwU-W5cJccgPw4ppARd48_pz5tbb8bbgIuB1BGIJF2Hhl8Q_GtCdc8RFCw","e":"AQAB","x5c":["MIICqTCCAZECBgGCApNoETANBgkqhkiG9w0BAQsFADAYMRYwFAYDVQQDDA1leGFtcGxlLXJlYWxtMB4XDTIyMDcxNTE1NTQ1MVoXDTMyMDcxNTE1NTYzMVowGDEWMBQGA1UEAwwNZXhhbXBsZS1yZWFsbTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAPKEGL+m37AcQ3q99h+rf2MM6vPWt6qKD3UjPvjyxEsjl8z/81bQzc680DxrEWeihOPr01TYEpKi/9jtriLaUTKnNRsAQXe4qgAi4XdyCpRp8EvpaAGIva1ymabPqwYLgOUwFqtyC/QUKOIB4NL+ozg792nLkB4lt1L2yukkU1SFiHj6zquDZXxw34toYEaYA+xgojcY3GccaV5EZxWip1VPVhh7N4FpwBUnr+nb8c8qaTLrcCltkTgpdDk41qgQDxwcERIMWmp01SkZhCzBM52FhPTnmVcFPluXCXHID8OKaQEXePP6c+bW2/G24CLgdQRiCRdh4ZfEPxrQnXPERQsCAwEAATANBgkqhkiG9w0BAQsFAAOCAQEAJ0m2sBUodNfPiZGcb3YiOsEFtwGoEB07CapWzZ4FzfpWzusS4MBB5tELHrQPV0MGqCC9sl0cPJHWg0rTnghB2rMT7EgW3hkxw1EUOEAwrzUwbUaOxlw4yNOe/fPT3e2sF6Sh4WHcWE55hANK5RTXtVPhYYzsXjrN32MCDdHKIqF4Lz/FMkAjLIVOfnpwJfa/Fr6mVZ1+n1D2crW1mXXQixxX2EKT2rkIu/98c4JG6nuiyuqLXuu6kxzZSDEMDK5oPM5/dxl103JRw65fxnz18UA7e+zvUCf+CexcAY5T2MaLdDHfLgL1AXt+oKXYTmLgN/4APNc7l/2okyx2Q+sKFg=="],"x5t":"ve-gipGvhhmuwP92oc-DM9AgNvw","x5t#S256":"Kq2i0SHjc6Kl6lDfc6zTFKBJ_TXT9REwtadFbYnJFw0"},{"kid":"jLmv63e0cg7sXeYSkYRqwcH041pC_1Pdf2JBsAz8yoU","kty":"RSA","alg":"RS256","use":"sig","n":"iYggW1KbFC1kG3MAg9ObXVRhEypviAKRstTpJzhSFhUILXf5diWh1Fym0Tyc61u_XUfkWbIsOZicQ1fXmG70vgZ8Tex-U7PKopIs0I1YuCHgWRxo7SMqvfuDFxFjlSLaD6ZsQ_htBFstmi7ArGbe96hVmfjk2QgPHLPTnpbSPh0oD1EOn_xvW3r0ucOk0nZtgncFLp4_Z7YH-wWfyxhpTOZiEQezG4vbiW7ivyMpQp_Y2AdmkkYUob2Lfe7bSqRH9PrG2zBPmwXjiXPy2kNRrFJdQ74R3kO_Ze2r0jGppdIMfBxeQQeEv6b-_qoEvm3PFWEnZJ73XGicsJa7p_0X3Q","e":"AQAB","x5c":["MIICqTCCAZECBgGCApNnijANBgkqhkiG9w0BAQsFADAYMRYwFAYDVQQDDA1leGFtcGxlLXJlYWxtMB4XDTIyMDcxNTE1NTQ1MFoXDTMyMDcxNTE1NTYzMFowGDEWMBQGA1UEAwwNZXhhbXBsZS1yZWFsbTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAImIIFtSmxQtZBtzAIPTm11UYRMqb4gCkbLU6Sc4UhYVCC13+XYlodRcptE8nOtbv11H5FmyLDmYnENX15hu9L4GfE3sflOzyqKSLNCNWLgh4FkcaO0jKr37gxcRY5Ui2g+mbEP4bQRbLZouwKxm3veoVZn45NkIDxyz056W0j4dKA9RDp/8b1t69LnDpNJ2bYJ3BS6eP2e2B/sFn8sYaUzmYhEHsxuL24lu4r8jKUKf2NgHZpJGFKG9i33u20qkR/T6xtswT5sF44lz8tpDUaxSXUO+Ed5Dv2Xtq9IxqaXSDHwcXkEHhL+m/v6qBL5tzxVhJ2Se91xonLCWu6f9F90CAwEAATANBgkqhkiG9w0BAQsFAAOCAQEAJnpyAUSeHTYgAlnIo25JTE22A6XKXlFWeTg1xr7boDGhCzvU76LpZm9O17axsV6xvz+Xv1G6jLudOfiSHKChWPJ6DKLx7la/NjmSbCD+cYq4dI0u5jIXlq+TKwh/j3OR7aryZdsOU8qe+JztsT2g067f438upQ5eCQqFaui2KjcG+YKTz2r7eYPVeNgWqKSqUMYzaeCfGqfB77uI/qJVRpihM7d1IQxqaVFXWV9QFvnMCME7sNpux9HR5maZ74iJoqJqnNJt+3n3fJ+V5EnUjDhYBymDgCAYdm9F6J7FYwu97B1pi/ylM3PZkLSw4lZOdGRrENcdUzfIF7/yrDkE0A=="],"x5t":"i84-Yy07kyxjbJsxCT9WqkIzb0Y","x5t#S256":"98lxIohuM-YCjadStpF5rwmKKZZ2a-I-kHXtazVb8Tk"}]}
                      """#
                   }
                   // If you want to use a remote JWKS provider, comment out local_jwks above, and
                   // uncomment the below remote_jwks configuration. There are coinciding configurations
                   // in ./gm/outputs/edge.cue that you will also need to uncomment.
                   // remote_jwks: {
                   //  http_uri: {
                   //   uri:     "\(endpoint)/auth/realms/\(realm)/protocol/openid-connect/certs"
                   //   cluster: "edge_to_keycloak" // this key should be unique across the mesh
                   //  }
                   // }
               }
           }
       }