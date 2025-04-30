# output nat instance ip
output "nat_instance_public_ip" {
  description = "Public IP dari NAT instance"
  value       = aws_eip.eip.public_ip
}

# output dns load balancer
output "load_balancer_dns_name" {
  description = "DNS Name dari Application Load Balancer"
  value       = aws_lb.lb.dns_name
}
