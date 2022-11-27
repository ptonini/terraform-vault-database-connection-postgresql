output "this" {
  value = vault_database_secret_backend_connection.this
}

output "database" {
  value = var.database
}

output "role" {
  value = postgresql_role.this
}