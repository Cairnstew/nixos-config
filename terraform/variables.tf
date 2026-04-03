variable "cloud_hosts" {
  description = "Map of cloud hosts to deploy"
  type = map(object({
    instance_type = string
    nixos_release = string
  }))
  default = {}
}