data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  tags = {
    Author = "Terraform"
  }
}

resource "aws_iam_role" "iam_role" {
  name = "${lower(var.env_code)}-${lower(var.project_code)}-mwaa"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = "mwaa"
        Principal = {
          Service = [
            "airflow-env.amazonaws.com",
            "airflow.amazonaws.com"
          ]
        }
      },
    ]
  })

  tags = merge(local.tags, {
    Name = "${lower(var.env_code)}-${lower(var.project_code)}-mwaa"
  })
}

data "aws_iam_policy_document" "iam_policy_document" {
  statement {
    sid       = ""
    actions   = ["airflow:PublishMetrics"]
    effect    = "Allow"
    resources = ["arn:aws:airflow:${var.aws_region}:${local.account_id}:environment/${var.project_code}"]
  }

  statement {
    sid     = ""
    actions = ["s3:ListAllMyBuckets"]
    effect  = "Allow"
    resources = [
      aws_s3_bucket.s3_bucket.arn,
      "${aws_s3_bucket.s3_bucket.arn}/*"
    ]
  }

  statement {
    sid = ""
    actions = [
      "s3:GetObject*",
      "s3:GetBucket*",
      "s3:List*"
    ]
    effect = "Allow"
    resources = [
      aws_s3_bucket.s3_bucket.arn,
      "${aws_s3_bucket.s3_bucket.arn}/*"
    ]
  }

  statement {
    sid       = ""
    actions   = ["logs:DescribeLogGroups"]
    effect    = "Allow"
    resources = ["*"]
  }

  statement {
    sid = ""
    actions = [
      "logs:CreateLogStream",
      "logs:CreateLogGroup",
      "logs:PutLogEvents",
      "logs:GetLogEvents",
      "logs:GetLogRecord",
      "logs:GetLogGroupFields",
      "logs:GetQueryResults",
      "logs:DescribeLogGroups"
    ]
    effect    = "Allow"
    resources = ["arn:aws:logs:${var.aws_region}:${local.account_id}:log-group:airflow-${var.project_code}*"]
  }

  statement {
    sid       = ""
    actions   = ["cloudwatch:PutMetricData"]
    effect    = "Allow"
    resources = ["*"]
  }

  statement {
    sid = ""
    actions = [
      "sqs:ChangeMessageVisibility",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes",
      "sqs:GetQueueUrl",
      "sqs:ReceiveMessage",
      "sqs:SendMessage"
    ]
    effect    = "Allow"
    resources = ["arn:aws:sqs:${var.aws_region}:*:airflow-celery-*"]
  }

  statement {
    sid = ""
    actions = [
      "kms:Decrypt",
      "kms:DescribeKey",
      "kms:GenerateDataKey*",
      "kms:Encrypt"
    ]
    effect        = "Allow"
    not_resources = ["arn:aws:kms:*:${local.account_id}:key/*"]
    condition {
      test     = "StringLike"
      variable = "kms:ViaService"
      values = [
        "sqs.${var.aws_region}.amazonaws.com"
      ]
    }
  }
}

resource "aws_iam_policy" "iam_policy" {
  name   = var.project_code
  path   = "/"
  policy = data.aws_iam_policy_document.iam_policy_document.json
}

resource "aws_iam_role_policy_attachment" "iam_role_policy_attachment" {
  role       = aws_iam_role.iam_role.name
  policy_arn = aws_iam_policy.iam_policy.arn
}
