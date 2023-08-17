# " {
#   value = module.server.public_ip
# }

output "public_dns" {
  value = module.server.public_dns
}

output "size" {
  value = module.server.size
}
