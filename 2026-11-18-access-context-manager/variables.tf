variable "project_id" {
  type        = string
  description = "Lab project ID. It is the scope of the scoped access policy and the only project inside the dry-run perimeter."
}

variable "org_id" {
  type        = string
  description = "Numeric organization ID. Access policies always belong to an organization; a project without an organization cannot use this lab."
}

variable "region" {
  type        = string
  description = "Default region for the provider and the test bucket."
  default     = "us-east4"
}

variable "name_prefix" {
  type        = string
  description = "Prefix for access level and perimeter names. Letters, digits and underscores only, starting with a letter."
  default     = "acm_lab"

  validation {
    condition     = can(regex("^[A-Za-z][A-Za-z0-9_]{0,30}$", var.name_prefix))
    error_message = "Use letters, digits and underscores, starting with a letter (access level names must match this)."
  }
}

variable "existing_access_policy_id" {
  type        = string
  description = "Numeric ID of an existing access policy to use instead of creating a scoped one. Leave empty to create a scoped policy for the lab project."
  default     = ""
}

variable "corp_cidrs" {
  type        = list(string)
  description = "Public office egress ranges, IPv4 or IPv6. Host bits must be zero (192.0.2.0/24 is valid, 192.0.2.1/24 is rejected). Replace the documentation ranges with your own."
  default     = ["203.0.113.0/24", "2001:db8:100::/48"]
}

variable "allowed_regions" {
  type        = list(string)
  description = "ISO 3166-1 alpha-2 country codes. Matched against the geolocation of the public source IP; private source IPs never match."
  default     = ["US", "CA"]
}

variable "business_hours_tz" {
  type        = string
  description = "IANA time zone used by the custom CEL level's business-hours check."
  default     = "America/Los_Angeles"
}

variable "enable_device_level" {
  type        = bool
  description = "Create a device-policy access level (screen lock, encryption, corp-owned). Device attributes need Endpoint Verification and a paid enterprise security subscription; the level can be created without them but will not be met."
  default     = false
}

variable "create_test_bucket" {
  type        = bool
  description = "Create a small Cloud Storage bucket in the lab project so the dry-run perimeter has something to log against."
  default     = true
}

variable "ingress_identities" {
  type        = list(string)
  description = "Identities allowed by the perimeter ingress rule, for example [\"user:you@example.com\"]. Leave empty to use ANY_IDENTITY (still limited by the access level and to Cloud Storage)."
  default     = []
}
