data "aws_iam_policy_document" "ec2_assume_role_for_ssm" {
  version = "2012-10-17"
  statement {
    sid    = "Ec2AssumeRoleForSSM"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
    actions = [
      "sts:AssumeRole",
    ]
  }
}

resource "aws_iam_role" "ec2_role_for_ssm" {
  name                = "ec2-role-for-ssm"
  assume_role_policy  = data.aws_iam_policy_document.ec2_assume_role_for_ssm.json
  managed_policy_arns = ["arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"]
  tags                = var.common_tags
}

resource "aws_iam_instance_profile" "ec2_role_for_ssm" {
  name = "ec2-ssm-instance-profile"
  role = aws_iam_role.ec2_role_for_ssm.name
  tags = var.common_tags
}
