output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.vpc.vpc_id
}

output "alb_dns_name" {
  description = "The DNS name of the load balancer"
  value       = var.enable_alb ? aws_lb.nomad[0].dns_name : ""
}

output "alb_zone_id" {
  description = "The zone ID of the load balancer"
  value       = var.enable_alb ? aws_lb.nomad[0].zone_id : ""
}

output "nomad_ui_url" {
  description = "URL for Nomad UI"
  value       = var.enable_alb ? "http://${aws_lb.nomad[0].dns_name}/ui/" : ""
}

output "api_url" {
  description = "URL for API endpoints"
  value       = var.enable_alb ? "http://${aws_lb.nomad[0].dns_name}/api" : ""
}

output "server_asg_name" {
  description = "Name of the server Auto Scaling Group"
  value       = aws_autoscaling_group.nomad_servers.name
}

output "client_asg_name" {
  description = "Name of the client Auto Scaling Group"
  value       = aws_autoscaling_group.nomad_clients.name
}

output "nomad_ui_target_group_arn" {
  description = "ARN of the Nomad UI target group"
  value       = var.enable_alb ? aws_lb_target_group.nomad_ui[0].arn : ""
}

output "api_target_group_arn" {
  description = "ARN of the API target group"
  value       = var.enable_alb ? aws_lb_target_group.gengine_api[0].arn : ""
}

output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value       = module.vpc.private_subnets
}

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = module.vpc.public_subnets
}

output "bastion_public_ip" {
  description = "Public IP of the bastion host"
  value       = var.enable_bastion ? aws_instance.bastion[0].public_ip : ""
}

output "webhook_url" {
  description = "URL for GitHub webhook"
  value       = var.enable_bastion ? "http://${aws_instance.bastion[0].public_ip}:9000/hooks/terragrunt-deploy" : ""
}

output "app_runner_service_url" {
  description = "URL of the App Runner service"
  value       = var.enable_app_runner ? "https://${aws_apprunner_service.gengine_api[0].service_url}" : ""
}

output "app_runner_service_arn" {
  description = "ARN of the App Runner service"
  value       = var.enable_app_runner ? aws_apprunner_service.gengine_api[0].arn : ""
}