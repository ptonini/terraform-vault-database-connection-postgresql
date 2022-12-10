resource "random_password" "this" {
  length  = 16
  special = false
}

resource "postgresql_role" "this" {
  provider            = postgresql
  name                = "${var.role_name_prefix}-${var.database}"
  login               = true
  password            = random_password.this.result
  create_role         = true
  skip_reassign_owned = var.skip_reassign_owned
  roles = [
    "postgres"
  ]
  search_path = []
}

resource "vault_database_secret_backend_connection" "this" {
  name              = var.database
  backend           = try(var.backend.path, var.backend)
  verify_connection = var.verify_connection
  root_rotation_statements = [
    "ALTER ROLE \"${postgresql_role.this.name}\" WITH PASSWORD '{{password}}';"
  ]
  postgresql {
    connection_url = "postgres://{{username}}:{{password}}@${var.host}/${var.database}?sslmode=${var.ssl_mode}"
    username       = "${postgresql_role.this.name}${var.login_name_suffix}"
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

resource "vault_generic_endpoint" "rotate_root" {
  path                 = "${vault_database_secret_backend_connection.this.backend}/rotate-root/${vault_database_secret_backend_connection.this.name}"
  ignore_absent_fields = true
  disable_read         = true
  disable_delete       = true
  data_json            = "{}"
  depends_on = [
    vault_database_secret_backend_connection.this
  ]
}