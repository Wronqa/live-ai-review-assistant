output "worker_ecr_repository_url" {
  value = module.review_worker_ecr.repository_url
}

output "dispatcher_ecr_repository_url" {
   value = module.dispatcher_ecr.repository_url 
}
