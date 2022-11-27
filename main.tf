resource "random_password" "this" {
  length  = 16
  special = false
}

resource "postgresql_role" "this" {
  provider = postgresql
  name = "${var.role_name_prefix}-${var.database}"
  login = true
  password = random_password.this.result
  create_role = true
  skip_reassign_owned = var.skip_reassign_owned
  roles = [
    "postgres"
  ]
  search_path = []
}

resource "vault_database_secret_backend_connection" "this" {
  name = var.database
  backend = try(var.backend.path, var.backend)
  verify_connection = var.verify_connection
  root_rotation_statements = [
    "ALTER ROLE \"${postgresql_role.this.name}\" WITH PASSWORD '{{password}}';"
  ]
  postgresql {
    connection_url = "postgres://{{username}}:{{password}}@${var.host}/${var.database}?sslmode=require"
    username = "${postgresql_role.this.name}${var.login_name_suffix}"
  }
  data = {
    username = "${postgresql_role.this.name}${var.login_name_suffix}"
    password = postgresql_role.this.password
  }
  allowed_roles = var.allowed_roles
  lifecycle {
    ignore_changes = [
      postgresql
    ]
  }
}

resource "null_resource" "rotate_role_password" {
  triggers = {
    password = vault_database_secret_backend_connection.this.data.password
  }
  provisioner "local-exec" {
    command = "VAULT_TOKEN=${var.vault_token} vault write -force ${vault_database_secret_backend_connection.this.backend}/rotate-root/${vault_database_secret_backend_connection.this.name}"
  }
  depends_on = [
    vault_database_secret_backend_connection.this
  ]
}