variable "tenancy_name" {}
variable "tenancy_ocid" {}
variable "user_ocid" {}
variable "fingerprint" {}
variable "private_key_path" {}
variable "compartment_ocid" {}
variable "region" {}
variable "ssh_public_key" {}

provider "oci" {
	version         	= ">= 3.0.0"
	tenancy_ocid 		= "${var.tenancy_ocid}"
	user_ocid 			= "${var.user_ocid}"
	fingerprint 		= "${var.fingerprint}"
	private_key_path 	= "${var.private_key_path}"
	region 				= "${var.region}"
}

data "oci_identity_availability_domains" "ADs" {
  compartment_id = "${var.tenancy_ocid}"
}

output "tenancy_name" {
	value = ["${var.tenancy_name}"]
}

output "region" {
	value = ["${var.region}"]
}

output "ADS" {
 value = ["${data.oci_identity_availability_domains.ADs.availability_domains}"] 
} 

output "ADSnames" {
	value = ["${lookup(data.oci_identity_availability_domains.ADs.availability_domains[2],"name")}"] 
} 
 
resource "oci_core_virtual_network" "myfirstvm_vcn" {
  cidr_block = "192.168.0.0/16"
  dns_label = "andi"
  compartment_id = "${var.compartment_ocid}"
  display_name = "myfirstvm_vcn"
}


resource "oci_core_subnet" "myfirstvm_subnet1" {
    display_name 		= "myfirstvm_subnet1"
	availability_domain = "${lookup(data.oci_identity_availability_domains.ADs.availability_domains[0],"name")}"
    cidr_block 			= "192.168.1.0/24"
    compartment_id 		= "${var.compartment_ocid}"
    vcn_id 				= "${oci_core_virtual_network.myfirstvm_vcn.id}"
	route_table_id      = "${oci_core_route_table.myfirstvm_RT.id}"
	security_list_ids   = ["${oci_core_security_list.myfirstvm_SL.id}"]
}

resource "oci_core_internet_gateway" "myfirstvm_IGW" {
  compartment_id = "${var.compartment_ocid}"
  display_name   = "myfirstvm_IGW"
  vcn_id         = "${oci_core_virtual_network.myfirstvm_vcn.id}"
}

resource "oci_core_route_table" "myfirstvm_RT" {
  compartment_id = "${var.compartment_ocid}"
  vcn_id         = "${oci_core_virtual_network.myfirstvm_vcn.id}"
  display_name   = "myfirstvm_RT"

  route_rules {
    cidr_block        = "0.0.0.0/0"
    network_entity_id = "${oci_core_internet_gateway.myfirstvm_IGW.id}"
  }
}

resource "oci_core_security_list" "myfirstvm_SL" {
  display_name   = "public"
  compartment_id = "${var.compartment_ocid}"
  vcn_id         = "${oci_core_virtual_network.myfirstvm_vcn.id}"

  // EGRESS
  egress_security_rules = [{
    protocol    = "all"
    destination = "0.0.0.0/0"
  }]

  // INGRESS
  ingress_security_rules = [{
    tcp_options {
      "max" = 22
      "min" = 22
    }
    protocol = "6"
    source   = "0.0.0.0/0"
  },
    {
      tcp_options {
        "max" = 80
        "min" = 80
      }
      protocol = "6"
      source   = "0.0.0.0/0"
    },
    {
      tcp_options {
        "max" = 443
        "min" = 443
      }
      protocol = "6"
      source   = "0.0.0.0/0"
    },
    {
      icmp_options {
        "type" = 0
      }
      protocol = 1
      source   = "0.0.0.0/0"
    },
    {
      icmp_options {
        "type" = 3
        "code" = 4
      }
      protocol = 1
      source   = "0.0.0.0/0"
    },
    {
      icmp_options {
        "type" = 8
      }
      protocol = 1
      source   = "0.0.0.0/0"
    },
  ]
}


resource "oci_core_instance" "myfirstvm" {
  availability_domain = "${lookup(data.oci_identity_availability_domains.ADs.availability_domains[0],"name")}"
  compartment_id      = "${var.compartment_ocid}"
  display_name        = "myfirstVM"
  // image IDs https://docs.cloud.oracle.com/iaas/images/image/96b34fe9-627c-45a0-bcdf-d722ea5d5e4b/ 
  // image               = "ocid1.image.oc1.eu-frankfurt-1.aaaaaaaaitzn6tdyjer7jl34h2ujz74jwy5nkbukbh55ekp6oyzwrtfa4zma" 
  // LHR ocid1.image.oc1.uk-london-1.aaaaaaaa32voyikkkzfxyo4xbdmadc2dmvorfxxgdhpnk6dw64fa3l4jh7wa
  // PHX ocid1.image.oc1.phx.aaaaaaaaoqj42sokaoh42l76wsyhn3k2beuntrh5maj3gmgmzeyr55zzrwwa
  // IAD ocid1.image.oc1.iad.aaaaaaaageeenzyuxgia726xur4ztaoxbxyjlxogdhreu3ngfj2gji3bayda
  // FRA ocid1.image.oc1.eu-frankfurt-1.aaaaaaaaitzn6tdyjer7jl34h2ujz74jwy5nkbukbh55ekp6oyzwrtfa4zma
  source_details {
        source_id = "ocid1.image.oc1.iad.aaaaaaaageeenzyuxgia726xur4ztaoxbxyjlxogdhreu3ngfj2gji3bayda"
        source_type = "image"
		boot_volume_size_in_gbs = "60"
  }
  
  // VM.Standard2.1 VM.Standard2.2
  shape               = "VM.Standard2.1"
  subnet_id           = "${oci_core_subnet.myfirstvm_subnet1.id}"
  #hostname_label      = "anditest"

  metadata {
    ssh_authorized_keys = "${var.ssh_public_key}"
	user_data = "${base64encode(var.user-data)}"
  }
}

variable "user-data" {
  default = <<EOF
#!/bin/bash -x
echo '################### webserver userdata begins #####################'
# echo '########## yum update all ###############'
# yum update -y

echo '########## basic webserver ##############'
yum install -y httpd
systemctl enable  httpd.service
systemctl start  httpd.service

# simple webpage 
echo '<html><head></head><body>' > /var/www/html/index.html
echo '<H1>HELLO WORLD from myfirstVM </H1>' >> /var/www/html/index.html
echo '</body></html>' >> /var/www/html/index.html

# Linux firewall for http
firewall-offline-cmd --add-service=http
systemctl enable  firewalld
systemctl restart  firewalld

echo '################### webserver userdata ends #######################'
EOF
}


output "InstancePrivateIPs" {
	value = ["${oci_core_virtual_network.myfirstvm_vcn.cidr_block}"]
}

output "var.ssh_public_key" {
	value = ["${var.ssh_public_key}"]
}

output "Public IP of my first VM" {
	value = ["${oci_core_instance.myfirstvm.public_ip}"]
}

output "sshCmd" {
    value = "${format("ssh -i  ~/id_rsa opc@%s", "${oci_core_instance.myfirstvm.public_ip}")}"
}

