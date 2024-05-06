################################################################################
# Karpenter controller IAM Role
################################################################################

output "iam_role_name" {
  description = "The name of the controller IAM role"
  value       = try(aws_iam_role.controller.name, null)
}

output "iam_role_arn" {
  description = "The Amazon Resource Name (ARN) specifying the controller IAM role"
  value       = try(aws_iam_role.controller.arn, null)
}

output "iam_role_unique_id" {
  description = "Stable and unique string identifying the controller IAM role"
  value       = try(aws_iam_role.controller.unique_id, null)
}

################################################################################
# Node Termination Queue
################################################################################

output "queue_arn" {
  description = "The ARN of the SQS queue"
  value       = try(aws_sqs_queue.this.arn, null)
}

output "queue_name" {
  description = "The name of the created Amazon SQS queue"
  value       = try(aws_sqs_queue.this.name, null)
}

output "queue_url" {
  description = "The URL for the created Amazon SQS queue"
  value       = try(aws_sqs_queue.this.url, null)
}

################################################################################
# Node Termination Event Rules
################################################################################

output "event_rules" {
  description = "Map of the event rules created and their attributes"
  value       = aws_cloudwatch_event_rule.this
}

################################################################################
# Node IAM Role
################################################################################

output "node_iam_role_name" {
  description = "The name of the node IAM role"
  value       = try(aws_iam_role.node.name, null)
}

output "node_iam_role_arn" {
  description = "The Amazon Resource Name (ARN) specifying the node IAM role"
  value       = try(aws_iam_role.node.arn, var.node_iam_role_arn)
}

output "node_iam_role_unique_id" {
  description = "Stable and unique string identifying the node IAM role"
  value       = try(aws_iam_role.node.unique_id, null)
}

################################################################################
# Access Entry
################################################################################

output "node_access_entry_arn" {
  description = "Amazon Resource Name (ARN) of the node Access Entry"
  value       = try(aws_eks_access_entry.node.access_entry_arn, null)
}

################################################################################
# Node IAM Instance Profile
################################################################################

output "instance_profile_arn" {
  description = "ARN assigned by AWS to the instance profile"
  value       = try(aws_iam_instance_profile.this.arn, null)
}

output "instance_profile_id" {
  description = "Instance profile's ID"
  value       = try(aws_iam_instance_profile.this.id, null)
}

output "instance_profile_name" {
  description = "Name of the instance profile"
  value       = try(aws_iam_instance_profile.this.name, null)
}

output "instance_profile_unique" {
  description = "Stable and unique string identifying the IAM instance profile"
  value       = try(aws_iam_instance_profile.this.unique_id, null)
}
