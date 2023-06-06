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
    assign_public_ip = "true"
    subnet_id        = var.subnet_vcn_ocid
  }
  # Add private key
  metadata = {
    ssh_authorized_keys = file(var.ssh_public_key_path)
  }

  agent_config {
    is_management_disabled = false
    is_monitoring_disabled = false
    plugins_config {
      desired_state = "ENABLED"
      name = "Bastion"
    }
  }

  provisioner "file" {
    source      = "setup-olamv2-ol8.sh"
    destination = "/tmp/setup-olamv2-ol8.sh"
    connection {
      type        = "ssh"
      host        = self.public_ip
      user        = "opc"
      private_key = file("server.key")
    }
  }

  provisioner "remote-exec" {
    inline = [
      "sudo chmod +x /tmp/setup-olamv2-ol8.sh",
      "sudo chown root:root /tmp/setup-olamv2-ol8.sh",
      "sudo /bin/bash /tmp/setup-olamv2-ol8.sh"
    ]
    connection {
      type        = "ssh"
      host        = self.public_ip
      user        = "opc"
      private_key = file(var.ssh_private_key_path)
    }
  }

}

output "connection_details" {
  description = "Instance Connection Details"
  value = <<EOF
  
  Private IP: ${oci_core_instance.instance.private_ip} 
  Public IP: ${oci_core_instance.instance.public_ip} 

EOF
}

