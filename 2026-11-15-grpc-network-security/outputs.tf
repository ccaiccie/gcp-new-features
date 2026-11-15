output "load_balancer_ip" {
  description = "Public IP of the HTTPS load balancer. Point grpcurl at this address on port 443."
  value       = google_compute_global_address.lab.address
}

output "backend_service" {
  description = "Backend service that uses HTTP/2 (H2C) to the MIG."
  value       = google_compute_backend_service.lab.id
}

output "health_check" {
  description = "TCP health check against the gRPC listener on port 9000."
  value       = google_compute_health_check.lab.id
}

output "security_policy" {
  description = "Cloud Armor policy attached to the backend service."
  value       = google_compute_security_policy.lab.id
}

output "grpcurl_unary" {
  description = "Example unary grpcurl command (self-signed cert, so -insecure is required)."
  value       = "grpcurl -insecure -proto hello.proto -d '{\"greeting\":\"hello\"}' ${google_compute_global_address.lab.address}:443 hello.HelloService/SayHello"
}
