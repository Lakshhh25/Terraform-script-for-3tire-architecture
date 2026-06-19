terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}
 
# Configure the AWS Provider
provider "aws" {
  region = "ap-south-1"
}
 
#VPC creation
resource "aws_vpc" "vpc1" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"
}
 
#public subnet in 1a
resource "aws_subnet" "pubsub1" {
  vpc_id            = aws_vpc.vpc1.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "ap-south-1a"
 
}
 
#public subnet in 1b
resource "aws_subnet" "pubsub2" {
  vpc_id            = aws_vpc.vpc1.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "ap-south-1b"
 
}
 
#private subnet in 1a
resource "aws_subnet" "pvtsub1" {
  vpc_id            = aws_vpc.vpc1.id
  cidr_block        = "10.0.11.0/24"
  availability_zone = "ap-south-1a"
 
}
 
#private subnet in 1b
resource "aws_subnet" "pvtsub2" {
  vpc_id            = aws_vpc.vpc1.id
  cidr_block        = "10.0.12.0/24"
  availability_zone = "ap-south-1b"
 
}
 
#Internet gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc1.id
}
 
 
#public route table
resource "aws_route_table" "pubrt" {
  vpc_id = aws_vpc.vpc1.id
 
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
 
}
 
#public rt and public subnet1 connection
resource "aws_route_table_association" "rtpubsub1" {
  subnet_id      = aws_subnet.pubsub1.id
  route_table_id = aws_route_table.pubrt.id
}
 
#public rt and public subnet2 connection
resource "aws_route_table_association" "rtpubsub2" {
  subnet_id      = aws_subnet.pubsub2.id
  route_table_id = aws_route_table.pubrt.id
}
 
#private route table
resource "aws_route_table" "pvtrt" {
  vpc_id = aws_vpc.vpc1.id
 
}
 
#private rt and private subnet1 connection
resource "aws_route_table_association" "rtpvtsub1" {
  subnet_id      = aws_subnet.pvtsub1.id
  route_table_id = aws_route_table.pvtrt.id
}
 
#private rt and private subnet2 connection
resource "aws_route_table_association" "rtpvtsub2" {
  subnet_id      = aws_subnet.pvtsub2.id
  route_table_id = aws_route_table.pvtrt.id
}
 
#Security group for ALB
resource "aws_security_group" "alb_sg" {
  name   = "alb-sg"
  vpc_id = aws_vpc.vpc1.id
}
 
#Inboud rule 
resource "aws_security_group_rule" "alb_inbound" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.alb_sg.id
}
 
#Security group for EC-2
resource "aws_security_group" "ec2_sg" {
  name   = "ec2-sg"
  vpc_id = aws_vpc.vpc1.id
}
 
#Inboud rule 
resource "aws_security_group_rule" "ec2_inbound" {
  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb_sg.id
  security_group_id        = aws_security_group.ec2_sg.id
}
 
#Security group for RDS
resource "aws_security_group" "rds_sg" {
  name   = "rds-sg"
  vpc_id = aws_vpc.vpc1.id
}
 
#Inboud rule 
resource "aws_security_group_rule" "rds_inbound" {
  type                     = "ingress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.ec2_sg.id
  security_group_id        = aws_security_group.rds_sg.id
}
 
#EC-2 in private subnet1
resource "aws_instance" "web_1" {
  ami                    = "ami-010c86b8beee5a915"
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.pvtsub1.id
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
 
  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y httpd
    systemctl start httpd
    systemctl enable httpd
    echo "Hello from web-1" > /var/www/html/index.html
  EOF
 
}
 
#EC-2 in private subnet2
resource "aws_instance" "web_2" {
  ami                    = "ami-010c86b8beee5a915"
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.pvtsub2.id
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
 
  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y httpd
    systemctl start httpd
    systemctl enable httpd
    echo "Hello from web-2" > /var/www/html/index.html
  EOF
}
 
#application load balancer
resource "aws_lb" "app_lb" {
  name               = "app-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.pubsub1.id, aws_subnet.pubsub2.id]
 
  enable_deletion_protection = true
 
}
 
#Target group
resource "aws_lb_target_group" "aws_tg" {
  name     = "aws-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.vpc1.id
}
 
#Target group attachment to web 1
resource "aws_lb_target_group_attachment" "tg_web1" {
  target_group_arn = aws_lb_target_group.aws_tg.arn
  target_id        = aws_instance.web_1.id
  port             = 80
}
 
#Target group attachment to web 2
resource "aws_lb_target_group_attachment" "tg_web2" {
  target_group_arn = aws_lb_target_group.aws_tg.arn
  target_id        = aws_instance.web_2.id
  port             = 80
}
 
#Listner port 
resource "aws_lb_listener" "aws_listner" {
  load_balancer_arn = aws_lb.app_lb.arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.aws_tg.arn
  }
}
 
#RDS subnet group
resource "aws_db_subnet_group" "rds_subgrp" {
  name = "rds-subgrp"
 
  subnet_ids = [
    aws_subnet.pvtsub1.id,
    aws_subnet.pvtsub2.id
  ]
}
 
#RDS Mysql
resource "aws_db_instance" "rds" {
  allocated_storage    = 20
  db_name              = "rds_db"
  engine               = "mysql"
  engine_version       = "8.0"
  instance_class       = "db.t3.micro"
  username             = "admin"
  password             = "rootadmin123"
  parameter_group_name = "default.mysql8.0"
  db_subnet_group_name = aws_db_subnet_group.rds_subgrp.name
 
  vpc_security_group_ids = [
    aws_security_group.rds_sg.id
  ]
 
  publicly_accessible = false
  skip_final_snapshot = true
}
 
#S3 bucket
resource "aws_s3_bucket" "abmohan" {
  bucket = "abmohan"
}
 
#Version enabling in S3
resource "aws_s3_bucket_versioning" "buc_ver" {
  bucket = aws_s3_bucket.abmohan.id
 
  versioning_configuration {
    status = "Enabled"
  }
}
 
#cloud watch for EC2
resource "aws_cloudwatch_metric_alarm" "web1_cpu" {
  alarm_name          = "web1-cpu-utilization"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
 
  metric_name = "CPUUtilization"
  namespace   = "AWS/EC2"
 
  period    = 120
  statistic = "Average"
 
  threshold = 70
 
  dimensions = {
    InstanceId = aws_instance.web_1.id
  }
 
  alarm_description         = "Monitor CPU usage of web-1"
  insufficient_data_actions = []
}
 
#cloud watch for RDS
resource "aws_cloudwatch_metric_alarm" "rds_cpu" {
  alarm_name          = "rds-cpu-utilization"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
 
  metric_name = "CPUUtilization"
  namespace   = "AWS/RDS"
 
  period    = 120
  statistic = "Average"
 
  threshold = 70
 
  dimensions = {
    DBInstanceIdentifier = aws_db_instance.rds.id
  }
 
  alarm_description         = "Monitor CPU usage of RDS"
  insufficient_data_actions = []
}
