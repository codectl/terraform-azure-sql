module "naming" {
  source  = "codectl/naming/azure"
  version = "~> 0.1"

  suffix = ["demo", "dev"]
}

module "regions" {
  source  = "codectl/locations/azure"
  version = "~> 1.0"

  location = {
    primary = "germanywestcentral"
  }
}

module "rg" {
  source  = "codectl/rg/azure"
  version = "~> 1.0"

  groups = {
    demo = {
      name     = module.naming.resource_group.name_unique
      location = module.regions.location.primary.name
    }
  }
}

module "uai" {
  source  = "codectl/uai/azure"
  version = "~> 1.0"

  identity = {
    name                = module.naming.user_assigned_identity.name
    location            = module.rg.groups.demo.location
    resource_group_name = module.rg.groups.demo.name
  }
}

module "kv" {
  source  = "codectl/kv/azure"
  version = "~> 1.0"

  vault = {
    name                = module.naming.key_vault.name_unique
    location            = module.rg.groups.demo.location
    resource_group_name = module.rg.groups.demo.name

    purge_protection_enabled   = true
    soft_delete_retention_days = 7

    secrets = {
      random_string = {
        sql = {
          length  = 24
          special = true
        }
      }
    }

    keys = {
      tde = {
        key_type = "RSA"
        key_size = 2048
        key_opts = ["unwrapKey", "wrapKey"]
      }
    }
  }
}

module "rbac" {
  source  = "codectl/rbac/azure"
  version = "~> 1.0"

  role_assignments = {
    sql-identity = {
      object_id = module.uai.identity.principal_id
      type      = "ServicePrincipal"
      roles = {
        "Key Vault Crypto Service Encryption User" = {
          scopes = {
            kv = { id = module.kv.vault.id }
          }
        }
      }
    }
  }
}

module "sql" {
  source  = "codectl/sql/azure"
  version = "~> 1.0"

  mssql_server = {
    name                              = module.naming.mssql_server.name_unique
    location                          = module.rg.groups.demo.location
    resource_group_name               = module.rg.groups.demo.name
    administrator_login_password      = module.kv.secrets.sql.value
    primary_user_assigned_identity_id = module.uai.identity.id

    identity = {
      type         = "UserAssigned"
      identity_ids = [module.uai.identity.id]
    }

    transparent_data_encryption = {
      key_vault_key_id      = module.kv.keys.tde.id
      auto_rotation_enabled = true
    }
  }

  depends_on = [module.rbac]
}
