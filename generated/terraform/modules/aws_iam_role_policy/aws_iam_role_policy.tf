resource "aws_iam_role_policy" "this" {
  name   = var.name
  role   = var.role
  policy = var.policy
}