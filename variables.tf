variable "prefix" {
  type = string
  default = "my-prefix"
  description = "This variable is used to unify all resource naming within this module"
}

variable "tags" {
  type = map(string)
  default = {}
  description = "This variable is used to refference same tags through all resources"
}