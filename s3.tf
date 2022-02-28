data "aws_canonical_user_id" "current" {}

data "aws_elb_service_account" "main" {}

resource "aws_s3_bucket" "imdb_lb_logs" {
  bucket = var.lb_log_bucket
  acl    = "private"

  policy = <<POLICY
{
  "Id": "Policy",
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "s3:PutObject"
      ],
      "Effect": "Allow",
      "Resource": "arn:aws:s3:::${var.lb_log_bucket}/AWSLogs/*",
      "Principal": {
        "AWS": [
          "${data.aws_elb_service_account.main.arn}"
        ]
      }
    }
  ]
}
POLICY

  tags = {
    Name    = "IMD_lb_logs"
    Project = "IMDB"
  }
}

# resource "aws_s3_bucket" "cf-logs" {
#   bucket = "joelcomanda-cf-logs"
#   acl    = "private"

#   policy = <<POLICY
# {
#   "Id": "Policy",
#   "Version": "2012-10-17",
#   "Statement": [
#     {
#       "Action": [
#         "s3:PutObject"
#       ],
#       "Effect": "Allow",
#       "Resource": "arn:aws:s3:::joelcomanda-cf-logs/cf-Logs/*",
#       "Principal": {
#         "AWS": [
#           "${data.aws_elb_service_account.main.arn}"
#         ]
#       }
#     }
#   ]
# }
# POLICY

#   tags = {
#     Name = "lb_logs"
#   }
# }
