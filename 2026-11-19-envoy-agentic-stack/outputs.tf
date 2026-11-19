output "load_balancer_ip" {
  description = "Global anycast address of the Envoy-based Application Load Balancer."
  value       = google_compute_global_address.lab.address
}

output "model_url" {
  description = "Path routed to the model stand-in."
  value       = "http://${google_compute_global_address.lab.address}/v1/chat/completions"
}

output "mcp_url" {
  description = "Path routed to the MCP stand-in."
  value       = "http://${google_compute_global_address.lab.address}/mcp"
}

output "rate_limit" {
  description = "Cloud Armor request-count threshold (not tokens)."
  value       = "${var.rate_limit_count} requests per ${var.rate_limit_interval_sec}s, exceed action deny(429)"
}

output "try_model" {
  description = "curl the model path."
  value       = "curl -sS http://${google_compute_global_address.lab.address}/v1/chat/completions"
}

output "try_mcp" {
  description = "curl the MCP path."
  value       = "curl -sS http://${google_compute_global_address.lab.address}/mcp"
}

output "try_rate_limit" {
  description = "Send enough requests to trip the request-count 429."
  value       = "for i in $(seq 1 20); do curl -sS -o /dev/null -w '%%{http_code}\\n' http://${google_compute_global_address.lab.address}/v1/chat/completions; done"
}
