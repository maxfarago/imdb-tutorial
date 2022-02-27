resource "aws_ssm_parameter" "rdspw" {
  name  = "rdspassword"
  type  = "String"
  value = var.dbpw
}

data "aws_db_snapshot" "imdb" {
  db_snapshot_identifier = "imdb-rds-snapshot"
  include_shared         = true
}

resource "aws_db_instance" "imdb" {
  allocated_storage      = 10
  snapshot_identifier    = data.aws_db_snapshot.imdb.db_snapshot_identifier
  instance_class         = "db.t3.micro"
  db_subnet_group_name   = aws_db_subnet_group.private.name
  vpc_security_group_ids = [aws_security_group.imdb_sg.id]
  username               = "postgres"
  password               = aws_ssm_parameter.rdspw.value
  skip_final_snapshot    = true
}