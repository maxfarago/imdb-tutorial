output "rds_endpoint" {
  value = aws_db_instance.imdb.endpoint
}

output "api_public_ip" {
  value = aws_instance.imdb.public_ip
}

output "lb_endpoint" {
  value = aws_lb.imdb.dns_name
}