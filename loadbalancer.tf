resource "aws_lb" "imdb" {
  name               = "imdb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.allow_tls.id]
  subnets = [
    aws_subnet.public1.id,
    aws_subnet.public2.id,
  ]

  enable_deletion_protection = false

  access_logs {
    bucket  = aws_s3_bucket.imdb_lb_logs.bucket
    enabled = true
  }

  tags = {
    Project = "IMDB"
  }
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.imdb.arn
  port              = 3000
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_acm_certificate_validation.cert_validation.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api_server.arn
  }
}

resource "aws_lb_listener_certificate" "listener_cert" {
  listener_arn    = aws_lb_listener.https.arn
  certificate_arn = aws_acm_certificate.acm_cert.arn
}

resource "aws_lb_target_group" "api_server" {
  name     = "api-server"
  port     = 3000
  protocol = "HTTP"
  vpc_id   = aws_vpc.vpc1.id
  health_check {
    enabled  = true
    path     = "/"
    port     = 80
    protocol = "HTTP"
    matcher  = 200
  }

  stickiness {
    type            = "lb_cookie"
    cookie_duration = 14400
  }
}

resource "aws_lb_target_group_attachment" "imdb" {
  target_group_arn = aws_lb_target_group.api_server.arn
  target_id        = aws_instance.imdb.id
  port             = 3000
}