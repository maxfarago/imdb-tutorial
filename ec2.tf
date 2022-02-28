### IMDB INSTANCE RUNNNG API ###
resource "aws_instance" "imdb" {
  ami                    = var.ami
  instance_type          = var.instance_type
  key_name               = var.key_pair
  subnet_id              = aws_subnet.private1.id
  vpc_security_group_ids = [aws_security_group.api_server.id]

  depends_on = [
    aws_db_instance.imdb,
  ]

  credit_specification {
    cpu_credits = "unlimited"
  }

  tags = {
    Name    = "IMDB_API"
    Project = "IMDB"
  }

  user_data = <<HEREDOC
#! /bin/bash
mkdir /home/ec2-user/imdb
mkdir /home/ec2-user/imdb/data
cd /home/ec2-user/imdb/data
sudo wget https://datasets.imdbws.com/title.basics.tsv.gz
sudo gunzip title.basics.tsv.gz
sudo tail -n +2 title.basics.tsv > title.basics.noheader.tsv
sudo rm title.basics.tsv
yum -y update
sudo tee /etc/yum.repos.d/pgdg.repo <<EOF
  [pgdg12]
  name=PostgreSQL 12 for RHEL/CentOS 7 - x86_64
  baseurl=https://download.postgresql.org/pub/repos/yum/12/redhat/rhel-7-x86_64
  enabled=1
  gpgcheck=0
EOF
yum makecache
yum install -y postgresql12 postgresql12-server
cd ..
sudo wget https://github.com/PostgREST/postgrest/releases/download/v7.0.1/postgrest-v7.0.1-linux-x64-static.tar.xz
sudo tar xJf postgrest-v7.0.1-linux-x64-static.tar.xz
sudo mv postgrest /usr/bin/postgrest
sudo tee imdb.conf <<EOF
  db-uri = "postgres://postgres:${aws_ssm_parameter.rdspw.value}@${aws_db_instance.imdb.endpoint}:5432/postgres"
  db-schema = "api"
  db-anon-role = "web_api"
  db-pool = 10
EOF
sudo tee /etc/systemd/system/postgrest.service <<EOF
  [Unit]
  Description=REST API for the IMDb database

  [Service]
  User=ec2-user

  WorkingDirectory=/home/ec2-user/imdb

  ExecStart=/usr/bin/postgrest /home/ec2-user/imdb/imdb.conf
  SuccessExitStatus=143
  TimeoutStopSec=10
  Restart=on-failure
  RestartSec=5

  [Install]
  WantedBy=multi-user.target
EOF
sudo systemctl enable postgrest
sudo systemctl start postgrest
HEREDOC
}