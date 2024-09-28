resource "aws_iam_role" "this" {
  name               = var.name
  description        = var.description
  assume_role_policy = var.assume_role_policy

  dynamic "inline_policy" {
    for_each = var.inline_policy
    content {
      name   = inline_policy.value["name"]
      policy = inline_policy.value["policy"]
    }
  }
  force_detach_policies = var.force_detach_policies
  tags                  = var.tags
}


