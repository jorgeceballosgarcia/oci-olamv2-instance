instance_name       = "oci-olamv2-instance"
instance_shape      = "VM.Standard.E4.Flex"
ssh_public_key_path = "server.key.pub"
ssh_private_key_path    = "server.key"
region              = "eu-milan-1"
os                  = "Oracle Linux"
os_image_build      = "^Oracle-Linux-8([\\.0-9-]+)$"
memory_in_gbs       = "16"
ocpus               = "2"
compartment_ocid    = "ocid1.compartment.oc1..XXXXX"
subnet_vcn_ocid     = "ocid1.subnet.oc1.eu-XXXXX"