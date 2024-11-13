terraform {
  backend "azurerm" {
    resource_group_name  = ""
    storage_account_name = ""
    container_name       = "terraformstate"
    key                  = "Terraform.tfstate"
    access_key           = ""            
    subscription_id      = ""
    tenant_id            = ""
  }
  required_providers {
    azurerm = {
      # The "hashicorp" namespace is the new home for the HashiCorp-maintained
      # provider plugins.
      #
      # source is not required for the hashicorp/* namespace as a measure of
      # backward compatibility for commonly-used providers, but recommended for
      # explicitness.
      source  = "hashicorp/azurerm"
      version = "~> 3.1"
    }
    null = {
      # source is required for providers in other namespaces, to avoid ambiguity.
      source  = "hashicorp/null"
      version = "~> 3.1.0"
    }
  }
}
provider "azurerm" {
  # whilst the `version` attribute is optional, we recommend pinning to a given version of the Provider  
  features {
    
  }
  subscription_id = ""
  //subscription name

}
provider "vsphere" {
  user                 = var.vsphere_user
  password             = var.vsphere_password
  vsphere_server       = var.vsphere_server
  //because we don't have certificate on vcenter 
  allow_unverified_ssl = true
  //Declare vsphere on premise environment
}

// Active Directory variables and Provider
variable "domaincontroller" { default = "" }
variable "domainadmin" {default = ""}
variable "domainadminpassword" {default = ""}
provider "ad" {
  winrm_hostname = var.domaincontroller
  winrm_username = var.domainadmin
  winrm_password = var.domainadminpassword
  krb_realm      = "domain.co.nz"
}
//Declare Data Center
data "vsphere_datacenter" "datacenter" {
    name = "dc name"
}

//Declare Datastore
data "vsphere_datastore" "datastore" {
  name          = "storage name"
  datacenter_id = data.vsphere_datacenter.datacenter.id
}

//Declare Storage Policy
data "vsphere_storage_policy" "threepar_policy" {
  name = "Data Reduction"
}

//Declare Data center Cluster
data "vsphere_compute_cluster" "cluster" {
  name = "NZAKLCLUSTER01"
  datacenter_id = data.vsphere_datacenter.datacenter.id
}

//Declare Network VLAN
data "vsphere_network" "VLAN_name" {
  name          = "VLAN_name"
  datacenter_id = data.vsphere_datacenter.datacenter.id
}

//Declare Template for Almalinux 8 and uuid
data "vsphere_virtual_machine" "Almalinux8_template" {
  //tempalte name
  name = "[TEMPLATE] AlmaLinux 8 - Image v0.0.2"
  datacenter_id = data.vsphere_datacenter.datacenter.id
  //uuid of template
  uuid = "421d21ae-a0ff-c51f-0582-90d994ae3e8b"
  
}

// Declare Storage resource and policy
resource "vsphere_virtual_machine" "vm" {
  name              = var.vsphere_virtual_machine-name
  resource_pool_id  = data.vsphere_compute_cluster.cluster.resource_pool_id
  datastore_id      = data.vsphere_datastore.datastore.id
  storage_policy_id = data.vsphere_storage_policy.threepar_policy.id
  num_cpus          = 2
  memory            = 4096
  guest_id          = "rhel8_64Guest"
  scsi_type         = "lsilogic-sas"
  firmware          = data.vsphere_virtual_machine.Almalinux8_template.firmware
  // Declare Vmware Tools Opions
  tools_upgrade_policy = "upgradeAtPowerCycle"
  sync_time_with_host  = true
  run_tools_scripts_after_power_on = true
  run_tools_scripts_after_resume = true
  run_tools_scripts_before_guest_reboot = true
  run_tools_scripts_before_guest_shutdown = true

  //Network Interface
  network_interface {
    //adapter_type VMXNET3
    adapter_type = "vmxnet3"
    network_id = data.vsphere_network.Cert_Core_network.id
  }
  //Clone from a template
  clone {
    template_uuid = data.vsphere_virtual_machine.Almalinux8_template.uuid
    //wait for customization Timeout settings
    timeout = 20
    customize {
      linux_options {
        host_name = var.vsphere_virtual_machine-name
        domain = "domain.co.nz"
      }
      //Network card and Ip information, DNS servers      
      network_interface {
        ipv4_address = "10.10.x.x"
        ipv4_netmask = "25"
      }
      ipv4_gateway = "10.10.x.x"
      dns_server_list = ["10.10.x.x","10.10.x.x"]
    } 
  }
  //Disk information
  disk {
    label = "disk0"
    size  = 30
    storage_policy_id = data.vsphere_storage_policy.threepar_policy.id
  }
}
