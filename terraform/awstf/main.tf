terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.25.0"
    }
  }
}

provider "aws" {
	region 	= var.aws_region
}

resource "tls_private_key" "ssh" {
	algorithm = "RSA" 
	rsa_bits  = 2048
}

resource "local_file" "ssh_private_key" {
	content = tls_private_key.ssh.private_key_openssh
	filename = format("/px-deploy/.px-deploy/keys/id_rsa.aws.%s",var.config_name)
}

resource "local_file" "ssh_public_key" {
	content = tls_private_key.ssh.public_key_openssh
	filename = format("/px-deploy/.px-deploy/keys/id_rsa.aws.%s.pub",var.config_name)
}

resource "aws_key_pair" "deploy_key" {
	key_name = format("px-deploy.%s",var.config_name)
	public_key = tls_private_key.ssh.public_key_openssh
}

resource "aws_vpc" "vpc" {
	cidr_block	= var.aws_cidr_vpc
	enable_dns_hostnames	= false
	enable_dns_support		= true
	tags = {
		Name = format("%s.%s-%s",var.name_prefix,var.config_name,"vpc")
        px-deploy_name = var.config_name
	}
}

resource "aws_subnet" "subnet" {
	vpc_id 					=	aws_vpc.vpc.id
	cidr_block 				= 	var.aws_cidr_sn
	#availability_zone 		= 	var.aws_az
	tags = {
		Name = format("%s-%s-%s",var.name_prefix,var.config_name,"subnet")
        px-deploy_name = var.config_name
		}
}

resource "aws_internet_gateway" "igw" {
	vpc_id = aws_vpc.vpc.id
	tags = {
		Name = format("%s-%s-%s",var.name_prefix,var.config_name,"igw")
        px-deploy_name = var.config_name
	}
}

resource "aws_route_table" "rt" {
	vpc_id = aws_vpc.vpc.id
	route {
		cidr_block = "0.0.0.0/0"
		gateway_id = aws_internet_gateway.igw.id
	}
	tags = {
		Name = format("%s-%s-%s",var.name_prefix,var.config_name,"rt")
	}  
}

resource "aws_route_table_association" "rt" {
	subnet_id = aws_subnet.subnet.id
	route_table_id = aws_route_table.rt.id
}

resource "aws_security_group" "sg_px-deploy" {
	name 		= 	"px-deploy"
	description = 	"Security group for px-deploy (tf-created)"
	vpc_id = aws_vpc.vpc.id
	ingress {
		description = "ssh"
		from_port 	= 22
		to_port 	= 22
		protocol	= "tcp"
		cidr_blocks = ["0.0.0.0/0"]
		}
	ingress {
		description = "http"
		from_port 	= 80
		to_port 	= 80
		protocol	= "tcp"
		cidr_blocks = ["0.0.0.0/0"]
		}
   	ingress {
		description = "https"
		from_port 	= 443
		to_port 	= 443
		protocol	= "tcp"
		cidr_blocks = ["0.0.0.0/0"]
		}
    ingress {
		description = "tcp 2382"
		from_port 	= 2382
		to_port 	= 2382
		protocol	= "tcp"
		cidr_blocks = ["0.0.0.0/0"]
		}
    ingress {
		description = "tcp 5900"
		from_port 	= 5900
		to_port 	= 5900
		protocol	= "tcp"
		cidr_blocks = ["0.0.0.0/0"]
		}
    ingress {
		description = "tcp 8080"
		from_port 	= 8080
		to_port 	= 8080
		protocol	= "tcp"
		cidr_blocks = ["0.0.0.0/0"]
		}
    ingress {
		description = "tcp 8443"
		from_port 	= 8443
		to_port 	= 8443
		protocol	= "tcp"
		cidr_blocks = ["0.0.0.0/0"]
		}
    ingress {
		description = "k8s nodeport"
		from_port 	= 30000
		to_port 	= 32767
		protocol	= "tcp"
		cidr_blocks = ["0.0.0.0/0"]
		}

    ingress {
		description = "tcp ingress all from vpc"
		from_port 	= 0
		to_port 	= 0
		protocol	= "tcp"
		cidr_blocks = [aws_vpc.vpc.cidr_block]
		}

	egress {
		from_port   = 0
		to_port     = 0
		protocol    = "-1"
		cidr_blocks = ["0.0.0.0/0"]
		}
	tags = {
		  px-deploy_name = var.config_name
		}
}


resource "aws_instance" "master" {
	for_each 					=	var.masters
	ami 						= 	var.aws_ami_image
	instance_type				=	var.aws_instance_type
	//availability_zone 		= 	var.aws_az
	vpc_security_group_ids 		=	[aws_security_group.sg_px-deploy.id]
	subnet_id					=	aws_subnet.subnet.id
	private_ip 					= 	each.value
	associate_public_ip_address = true
	//iam_instance_profile    	=   var.aws_iam_profile
	//source_dest_check			= 	false
	key_name 					= 	aws_key_pair.deploy_key.key_name
	root_block_device {
	  volume_size				=	50
	  delete_on_termination 	= true
	}
	user_data 				= 	base64encode(local_file.cloud-init-master[each.key].content)
	tags 					= {
								Name = each.key
								px-deploy_name = var.config_name
								px-deploy_username = var.PXDUSER
	}
}

resource "aws_instance" "node" {
	for_each 					=	var.nodes
	ami 						= 	var.aws_ami_image
	instance_type				=	each.value.instance_type
	//availability_zone 		= 	var.aws_az
	vpc_security_group_ids 		=	[aws_security_group.sg_px-deploy.id]
	subnet_id					=	aws_subnet.subnet.id
	private_ip 					= 	each.value.ip_address
	associate_public_ip_address = true
	//iam_instance_profile    	=   var.aws_iam_profile
	//source_dest_check			= 	false
	key_name 					= 	aws_key_pair.deploy_key.key_name
	root_block_device {
	  volume_size				=	50
	  delete_on_termination 	= true
	}
	user_data 				= 	base64encode(local_file.cloud-init-node[each.key].content)
	tags 					= {
								Name = each.key
								px-deploy_name = var.config_name
								px-deploy_username = var.PXDUSER
	}
}


resource "local_file" "cloud-init-master" {
	for_each = var.masters
	content = templatefile("${path.module}/cloud-init-master.tpl", { 
		tpl_pub_key = trimspace(tls_private_key.ssh.public_key_openssh),
		tpl_credentials = local.aws_credentials_array,
		tpl_master_scripts = base64gzip(data.local_file.master_scripts[each.key].content),
		tpl_env_scripts = base64gzip(data.local_file.env_script.content),
		tpl_name = each.key
		tpl_vpc = aws_vpc.vpc.id,
		tpl_sg = aws_security_group.sg_px-deploy.id,
		tpl_subnet = aws_subnet.subnet.id,
		tpl_gw = aws_internet_gateway.igw.id,
		tpl_routetable = aws_route_table.rt.id,
		tpl_ami = 	var.aws_ami_image,
		}
	)
	filename = "${path.module}/cloud-init-${each.key}-generated.yaml"
}

resource "local_file" "cloud-init-node" {
	for_each = var.nodes
	content = templatefile("${path.module}/cloud-init-node.tpl", { 
		tpl_pub_key = trimspace(tls_private_key.ssh.public_key_openssh),
		tpl_node_scripts = base64gzip(data.local_file.node_scripts[each.key].content),
		tpl_env_scripts = base64gzip(data.local_file.env_script.content),
		tpl_name = each.key
		tpl_vpc = aws_vpc.vpc.id,
		tpl_sg = aws_security_group.sg_px-deploy.id,
		tpl_subnet = aws_subnet.subnet.id,
		tpl_gw = aws_internet_gateway.igw.id,
		tpl_routetable = aws_route_table.rt.id,
		tpl_ami = 	var.aws_ami_image,
		}
	)
	filename = "${path.module}/cloud-init-${each.key}-generated.yaml"
}

resource "local_file" "aws-returns" {
	content = templatefile("${path.module}/aws-returns.tpl", { 
		tpl_vpc = aws_vpc.vpc.id,
		tpl_sg = aws_security_group.sg_px-deploy.id,
		tpl_subnet = aws_subnet.subnet.id,
		tpl_gw = aws_internet_gateway.igw.id,
		tpl_routetable = aws_route_table.rt.id,
		tpl_ami = 	var.aws_ami_image,
		}
	)
	filename = "${path.module}/aws-returns-generated.yaml"
}