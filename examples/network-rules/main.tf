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

module "kv" {
  source  = "codectl/kv/azure"
  version = "~> 1.0"

  vault = {
    name                = module.naming.key_vault.name_unique
    location            = module.rg.groups.demo.location
    resource_group_name = module.rg.groups.demo.name

    secrets = {
      random_string = {
        sql = {
          length  = 24
          special = true
        }
      }
    }
  }
}

module "network" {
  source  = "codectl/vnet/azure"
  version = "~> 1.0"


  vnet = {
    name                = module.naming.virtual_network.name
    location            = module.rg.groups.demo.location
    resource_group_name = module.rg.groups.demo.name
    address_space       = ["10.19.0.0/16"]

    subnets = {
      sales = {
        address_prefixes  = ["10.19.1.0/24"],
        service_endpoints = ["Microsoft.Sql"]
      }
      hr = {
        address_prefixes  = ["10.19.2.0/24"],
        service_endpoints = ["Microsoft.Sql"]
      }
    }
  }
}

module "sql" {
  source  = "codectl/sql/azure"
  version = "~> 1.0"

  mssql_server = {
    name                          = module.naming.mssql_server.name_unique
    location                      = module.rg.groups.demo.location
    resource_group_name           = module.rg.groups.demo.name
    administrator_login_password  = module.kv.secrets.sql.value
    public_network_access_enabled = true

    network_rules = {
      sales = {
        subnet_id = module.network.subnets.sales.id
      }
      hr = {
        subnet_id = module.network.subnets.hr.id
      }
    }
  }
}
