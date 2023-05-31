# Create datasource of images from the image list
data "oci_core_images" "images" {
  compartment_id = var.compartment_ocid
  operating_system = var.os
  filter {
    name = "display_name"
    values = [var.os_image_build]
    regex = true
  }
}

# Create datasource for availability domains
data "oci_identity_availability_domains" "ADs" {
  compartment_id = var.compartment_ocid
}

data "oci_bastion_sessions" "sessions" {
    bastion_id = var.bastion_ocid
    session_lifecycle_state = "ACTIVE"
}

data "oci_bastion_session" "active_session" {
    session_id = data.oci_bastion_sessions.sessions.sessions[0].id
}

# output "bastion_session_details" {
#     description = "Bastion Session SOCKS5"
#     value = data.oci_bastion_session.active_session.ssh_metadata.command
# }

output "connection_details" {
  description = "Bastion Connection Details"
  value = <<EOF
  
  Create Proxy Socks5: ${replace(data.oci_bastion_session.active_session.ssh_metadata.command, "ssh -i <privateKey> -N -D 127.0.0.1:<localPort> -p 22", "ssh -i bastion_GC3_sshkey -o \"ProxyCommand=nc -X connect -x www-proxy-ams.nl.oracle.com:80 %h %p\"  -N -D 127.0.0.1:20000 -p 22")} 
  Connect to instance: ${replace("ssh -i server.key opc@XX.XX.XX.XX -L 8444:127.0.0.2:443 -o ProxyCommand=\"nc -x 127.0.0.1:20000 %h %p\"", "XX.XX.XX.XX", oci_core_instance.instance.private_ip)}

EOF
}

resource "oci_core_instance" "instance" {
  availability_domain = data.oci_identity_availability_domains.ADs.availability_domains[0].name
  compartment_id      = var.compartment_ocid
  display_name        = var.instance_name
  shape               = var.instance_shape

  shape_config {
    #Optional
    memory_in_gbs = var.memory_in_gbs
    ocpus = var.ocpus
  }

  source_details {
    source_type = "image"
    source_id   = data.oci_core_images.images.images[0].id
    boot_volume_size_in_gbs = 100
  }

  create_vnic_details {
    assign_public_ip = "false"
    subnet_id        = var.subnet_vcn_ocid
  }
  # Add private key
  metadata = {
    ssh_authorized_keys = file(var.ssh_public_key_path)
    user_data           = base64encode(file("setup-olamv2-ol8.sh"))
  }

  agent_config {
    is_management_disabled = false
    is_monitoring_disabled = false
    plugins_config {
      desired_state = "ENABLED"
      name = "Bastion"
    }
  }

}

