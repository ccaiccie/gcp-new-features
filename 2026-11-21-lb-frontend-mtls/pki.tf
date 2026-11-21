# A small lab PKI built with the hashicorp/tls provider:
#   root CA -> intermediate CA -> client certificates
# plus a separate "rogue" root that the load balancer does not trust.
# Keys live in Terraform state and in ./certs. Lab use only.

locals {
  validity_hours = 24 * 90
}

# Root CA (trust anchor)
resource "tls_private_key" "root" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P256"
}

resource "tls_self_signed_cert" "root" {
  private_key_pem       = tls_private_key.root.private_key_pem
  is_ca_certificate     = true
  validity_period_hours = local.validity_hours
  allowed_uses          = ["cert_signing", "crl_signing", "client_auth"]
  subject {
    common_name  = "Lab Root CA"
    organization = "Network Technician lab"
  }
}

# Intermediate CA (uploaded as an intermediate in the trust store)
resource "tls_private_key" "intermediate" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P256"
}

resource "tls_cert_request" "intermediate" {
  private_key_pem = tls_private_key.intermediate.private_key_pem
  subject {
    common_name  = "Lab Issuing CA"
    organization = "Network Technician lab"
  }
}

resource "tls_locally_signed_cert" "intermediate" {
  cert_request_pem      = tls_cert_request.intermediate.cert_request_pem
  ca_private_key_pem    = tls_private_key.root.private_key_pem
  ca_cert_pem           = tls_self_signed_cert.root.cert_pem
  is_ca_certificate     = true
  validity_period_hours = local.validity_hours
  allowed_uses          = ["cert_signing", "crl_signing", "client_auth"]
}

# Client certificates, all issued by the intermediate except "rogue"
locals {
  clients = {
    # valid: EKU clientAuth, SPIFFE ID in a URI SAN
    good = { uses = ["digital_signature", "client_auth"], spiffe = "spiffe://lab.example/ns/payments/sa/client-1" }
    # no EKU extension at all: fails REJECT_INVALID, passes with ALLOW_MISSING_EKU
    noeku = { uses = ["digital_signature"], spiffe = "spiffe://lab.example/ns/legacy/sa/old-device" }
    # EKU present but serverAuth only: rejected even with ALLOW_MISSING_EKU
    serveronly = { uses = ["digital_signature", "server_auth"], spiffe = "spiffe://lab.example/ns/web/sa/server" }
  }
}

resource "tls_private_key" "client" {
  for_each    = local.clients
  algorithm   = "ECDSA"
  ecdsa_curve = "P256"
}

resource "tls_cert_request" "client" {
  for_each        = local.clients
  private_key_pem = tls_private_key.client[each.key].private_key_pem
  uris            = [each.value.spiffe]
  subject {
    common_name  = "lab-client-${each.key}"
    organization = "Network Technician lab"
  }
}

resource "tls_locally_signed_cert" "client" {
  for_each              = local.clients
  cert_request_pem      = tls_cert_request.client[each.key].cert_request_pem
  ca_private_key_pem    = tls_private_key.intermediate.private_key_pem
  ca_cert_pem           = tls_locally_signed_cert.intermediate.cert_pem
  validity_period_hours = local.validity_hours
  allowed_uses          = each.value.uses
}

# Rogue root and client: valid-looking, but the trust config does not know this CA
resource "tls_private_key" "rogue_root" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P256"
}

resource "tls_self_signed_cert" "rogue_root" {
  private_key_pem       = tls_private_key.rogue_root.private_key_pem
  is_ca_certificate     = true
  validity_period_hours = local.validity_hours
  allowed_uses          = ["cert_signing", "client_auth"]
  subject {
    common_name = "Rogue Root CA"
  }
}

resource "tls_private_key" "rogue_client" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P256"
}

resource "tls_cert_request" "rogue_client" {
  private_key_pem = tls_private_key.rogue_client.private_key_pem
  subject {
    common_name = "lab-client-rogue"
  }
}

resource "tls_locally_signed_cert" "rogue_client" {
  cert_request_pem      = tls_cert_request.rogue_client.cert_request_pem
  ca_private_key_pem    = tls_private_key.rogue_root.private_key_pem
  ca_cert_pem           = tls_self_signed_cert.rogue_root.cert_pem
  validity_period_hours = local.validity_hours
  allowed_uses          = ["digital_signature", "client_auth"]
}

# Server certificate for the load balancer frontend (self-signed, lab only)
resource "tls_private_key" "server" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "server" {
  private_key_pem       = tls_private_key.server.private_key_pem
  validity_period_hours = local.validity_hours
  dns_names             = [var.server_hostname]
  allowed_uses          = ["digital_signature", "key_encipherment", "server_auth"]
  subject {
    common_name = var.server_hostname
  }
}

# Files for the curl tests
resource "local_sensitive_file" "client_key" {
  for_each        = local.clients
  content         = tls_private_key.client[each.key].private_key_pem
  filename        = "${path.module}/certs/${each.key}.key"
  file_permission = "0600"
}

resource "local_file" "client_cert" {
  for_each = local.clients
  content  = tls_locally_signed_cert.client[each.key].cert_pem
  filename = "${path.module}/certs/${each.key}.crt"
}

resource "local_sensitive_file" "rogue_key" {
  content         = tls_private_key.rogue_client.private_key_pem
  filename        = "${path.module}/certs/rogue.key"
  file_permission = "0600"
}

resource "local_file" "rogue_cert" {
  content  = tls_locally_signed_cert.rogue_client.cert_pem
  filename = "${path.module}/certs/rogue.crt"
}

resource "local_file" "root_cert" {
  content  = tls_self_signed_cert.root.cert_pem
  filename = "${path.module}/certs/root.crt"
}

resource "local_file" "intermediate_cert" {
  content  = tls_locally_signed_cert.intermediate.cert_pem
  filename = "${path.module}/certs/intermediate.crt"
}
