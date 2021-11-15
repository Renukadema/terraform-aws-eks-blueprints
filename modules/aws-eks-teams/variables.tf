variable "enable_teams" {
  description = "Enable Teams"
  type        = bool
  default     = false
}
variable "teams" {
  description = "Map of maps of teams to create"
  type        = any
  default     = {}
}

variable "environment" {
  type = string
}

variable "tenant" {
  type = string
}

variable "zone" {
  type = string
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}