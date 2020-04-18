variable "admin_user" {
  type        = string
  default     = "batman"
  description = "Variable used to determine administrator username in VMSS instances"
}

variable "admin_pass" {
  type        = string
  default     = "S3cr3tu5M@x!mu$"
  description = "Variable used to determine administrator password in VMSS instances"
}