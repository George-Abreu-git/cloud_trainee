output "cluster_name" {
  description = "Nome do cluster ECS criado"
  value       = aws_ecs_cluster.main.name
}

output "service_name" {
  description = "Nome do serviço ECS criado"
  value       = aws_ecs_service.app.name
}

output "task_definition" {
  description = "ARN da task definition criada"
  value       = aws_ecs_task_definition.app.arn
}