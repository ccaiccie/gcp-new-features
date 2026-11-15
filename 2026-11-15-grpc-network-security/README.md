# gRPC behind an HTTPS load balancer, with Cloud Armor

Practice lab for the [gRPC for network and security engineers](https://github.com/ccaiccie/gcp-new-features/tree/main/2026-11-15-grpc-network-security) lesson. The lesson itself is vendor-neutral; this folder lives in the `gcp-new-features` repository because the lab is implemented on Google Cloud.

The configuration builds a small gRPC test server in a managed instance group, puts an external Application Load Balancer in front of it with an HTTP/2 cleartext (H2C) backend service and a health check, and attaches a Cloud Armor policy. TLS terminates at the load balancer on a lab-only self-signed certificate.

## Goals

- Place a gRPC backend behind HTTPS, with HTTP/2 from the load balancer to the instance.
- Attach a health check and a Cloud Armor security policy to that backend service.
- Call the service with `grpcurl` and see that HTTP/2 plus protobuf is not the same as a JSON REST API.
- Optionally tighten the Armor policy so only your address can establish a call.

## Prerequisites

- A Google Cloud project with billing enabled.
- Permissions to enable the Compute Engine API, and to create VPCs, instance groups, SSL certificates, backend services, forwarding rules, and Cloud Armor policies. Project Owner, or a combination of Compute Network Admin, Compute Instance Admin, and Compute Security Admin, is enough for a single-project lab.
- The [Google Cloud CLI](https://cloud.google.com/sdk), [Terraform](https://www.terraform.io/downloads) 1.6 or later, and [`grpcurl`](https://github.com/fullstorydev/grpcurl/releases).
- This lab generates a self-signed certificate with the Terraform `tls` provider. That is for practice only. Do not use it in production, and do not commit `terraform.tfvars` or state files (the repo `.gitignore` already excludes them).

The default container image is `moul/grpcbin`, a public gRPC test server that listens on TCP port 9000 without TLS. You can point `grpc_image` at another image that listens on the same port.

## Steps

1. Copy the example variables and set your project:

   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # edit project_id, and optionally region and zone
   ```

2. Initialize, review, and apply:

   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

   Terraform enables `compute.googleapis.com` (it does not disable it on destroy), then creates the VPC, a one-instance MIG running the sample server, a TCP health check on port 9000, an external Application Load Balancer with an H2C backend service, a self-signed cert, and a Cloud Armor policy.

3. Wait until the instance is healthy in the backend service. The first boot pulls a container, so this can take a few minutes:

   ```bash
   gcloud compute backend-services get-health grpc-lab-backend --global
   ```

## Verify with grpcurl

`hello.proto` in this folder matches the Hello service on the sample image. Replace `LB_IP` with `terraform output -raw load_balancer_ip`. The certificate is self-signed, so you must pass `-insecure` (not `-plaintext`; the client still uses TLS to the load balancer).

Unary call:

```bash
grpcurl -insecure -proto hello.proto \
  -d '{"greeting":"hello"}' \
  LB_IP:443 hello.HelloService/SayHello
```

Server streaming:

```bash
grpcurl -insecure -proto hello.proto \
  -d '{"greeting":"hello"}' \
  LB_IP:443 hello.HelloService/LotsOfReplies
```

If the image has reflection enabled, you can also list services:

```bash
grpcurl -insecure LB_IP:443 list
```

A useful security check: add your client address as an allow rule, change the default rule to `deny(403)`, apply, and confirm that a call from a different address is blocked at the load balancer. Remember that Cloud Armor can stop a gRPC call from being established, but it does not inspect later stream messages the way a JSON WAF inspects successive HTTP bodies.

## Cleanup

```bash
terraform destroy
```

This deletes the forwarding rule, certificate, backend, MIG, VPC, and Armor policy. It leaves the Compute Engine API enabled.

## Notes

- Serverless backends such as Cloud Run cannot be attached to a health check on an Application Load Balancer, which is why this lab uses a MIG.
- Official guidance for a backend service that uses the gRPC protocol is to use a gRPC or TCP health check, not HTTP or HTTP/2. The sample image may not implement `grpc.health.v1.Health`, so the lab uses TCP. In production, implement Health and switch the check to `grpc { port = 9000 }` so the load balancer expects `SERVING`.
- H2C is HTTP/2 over cleartext from the load balancer to the VM. The client still sees HTTPS on port 443. If you put a TLS-enabled server on the VM instead, change the backend protocol to `HTTP2` and use a `grpc` health check with TLS as appropriate.
- The Armor policy includes an example deny for `192.0.2.1/32` (TEST-NET-1) and a default allow. Tighten that before any real traffic.
