data "aws_route53_zone" "hosted_zone" {
  name         = var.hosted_zone
  private_zone = false
}

resource "aws_route53_record" "record_a" {
  zone_id = data.aws_route53_zone.hosted_zone.zone_id
  name    = var.new_sub_domain
  type    = "A"
  ttl = 300
  records = [aws_instance.imdb.public_ip]
  # alias {
  #   name                   = aws_instance.imdb.public_dns
  #   zone_id                = data.aws_route53_zone.hosted_zone.zone_id
  #   evaluate_target_health = true
  # }
}

resource "aws_route53_record" "cert_validation" {
  allow_overwrite = true
  name            = tolist(aws_acm_certificate.acm_cert.domain_validation_options)[0].resource_record_name
  records         = [tolist(aws_acm_certificate.acm_cert.domain_validation_options)[0].resource_record_value]
  type            = tolist(aws_acm_certificate.acm_cert.domain_validation_options)[0].resource_record_type
  zone_id         = data.aws_route53_zone.hosted_zone.id
  ttl             = 60
}

resource "aws_acm_certificate" "acm_cert" {
  domain_name       = var.new_sub_domain
  validation_method = "DNS"
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_acm_certificate_validation" "cert_validation" {
  timeouts {
    create = "10m"
  }
  certificate_arn         = aws_acm_certificate.acm_cert.arn
  validation_record_fqdns = [aws_route53_record.cert_validation.fqdn]
}
