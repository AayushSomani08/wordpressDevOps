provider "aws" {
    region = "us-east-1"
    
}
terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0.1"
    }
  }
}
provider "docker" {
      
      host    = "npipe:////.//pipe//docker_engine"
}

resource "aws_instance" "wordpress_ins" {
    ami = "ami-090230ed0c6b13c74"
    instance_type = "t4g.micro"
   vpc_security_group_ids = [aws_security_group.ec2_sg.id]
   tags = {
    Name="wordpress-instance"
   }
}
resource "aws_eip" "example" {
  instance = aws_instance.wordpress_ins.id # Provide the EC2 instance ID here
}


resource "aws_security_group" "rds_sg" {
  name        = "rds-security-group"
  description = "RDS security group"
}

resource "aws_security_group" "ec2_sg" {
  name        = "ec2-security-group"
  description = "EC2 security group"
}


resource "aws_security_group_rule" "rds_ingress_from_ec2" {
  type        = "ingress"
  from_port   = 3306
  to_port     = 3306
  protocol    = "tcp"
  cidr_blocks = [aws_security_group.ec2_sg.id]
  security_group_id = aws_security_group.rds_sg.id
}


resource "aws_db_instance" "wordpress_db" {
    allocated_storage    = 20
    storage_type        = "gp2"
    engine              = "mysql"
    engine_version      = "5.7"
    instance_class      = "db.t4g.micro"

    username            = "admin"
    password            = "password"
    parameter_group_name = "default.mysql5.7"
    skip_final_snapshot = true
    publicly_accessible = false

    vpc_security_group_ids = [aws_security_group.rds_sg.id]
  

}
    
  




resource "docker_container" "wordpress" {
  image = "wordpress:latest"  # Replace with your desired image
  name  = "wordpress-container"

  # Map ports to your host machine if needed
  ports {
    internal = 9000  # PHP-FPM port
    external = 80  # Map to a port on your host machine
  }
}

output "ec2_instance_id" {
  value = aws_instance.wordpress_ins.id
}

output "rds_instance_id" {
  value = aws_db_instance.wordpress_db.id
}


# Rollback and destroy behavior using explicit dependencies
resource "null_resource" "rollback_trigger" {
  triggers = {
    # Add any trigger that, if changed, would trigger a rollback
    instance_id = aws_instance.wordpress_ins.id
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_instance.wordpress_ins,
    aws_db_instance.wordpress_db
  ]

  provisioner "local-exec" {
    command = "echo Resources are being rolled back..."
    when    = destroy
  }
}