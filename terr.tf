provider "aws" {
  region = "us-east-1" // region name
}

resource "aws_vpc" "example_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "example_vpc"
  }
}

resource "aws_internet_gateway" "example_igw" {
  vpc_id = aws_vpc.example_vpc.id
  tags = {
    Name = "example_igw"
  }
}

resource "aws_subnet" "example_public_subnet_1" {
  vpc_id = aws_vpc.example_vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a" 
  tags = {
    Name = "example_public_subnet_1"
  }
}

resource "aws_subnet" "example_public_subnet_2" {
  vpc_id = aws_vpc.example_vpc.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "us-east-1b" 
  tags = {
    Name = "example_public_subnet_2"
  }
}

resource "aws_route_table" "example_public_rt" {
  vpc_id = aws_vpc.example_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.example_igw.id
  }
  tags = {
    Name = "example_public_rt"
  }
}

resource "aws_route_table_association" "example_public_rta_1" {
  subnet_id = aws_subnet.example_public_subnet_1.id
  route_table_id = aws_route_table.example_public_rt.id
}

resource "aws_route_table_association" "example_public_rta_2" {
  subnet_id = aws_subnet.example_public_subnet_2.id
  route_table_id = aws_route_table.example_public_rt.id
}

resource "aws_security_group" "example_sg" {
  name_prefix = "example_sg"
  description = "Allow inbound SSH and HTTP traffic"
  vpc_id = aws_vpc.example_vpc.id

  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "example_ec2_instance_1" {
  ami = "hereAMI"  # here will be AMI
  instance_type= "t2.micro" # Type of instance
  key_name = "example_key_pair" # SSH key
  vpc_security_group_ids = [aws_security_group.example_sg.id]
  subnet_id = aws_subnet.example_public_subnet_1.id
  associate_public_ip_address = true
  user_data = <<-EOF
              #!/bin/bash
              # installing Docker and Docker Compose
              sudo apt-get update
              sudo apt-get -y install apt-transport-https ca-certificates curl gnupg-agent software-properties-common
              curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
              sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
              sudo apt-get update
              sudo apt-get -y install docker-ce docker-ce-cli containerd.io docker-compose

              # cloning repo with configuration
              git clone https://github.com/prometheus/prometheus.git /home/ubuntu/prometheus
              cd /home/ubuntu/prometheus

              # creating network for monitoring
              docker network create prometheus

              # running Node-exporter and Cadvizor-exporter
              docker-compose -f examples/metrics/docker-compose.yml up -d

              # running Prometheus
              docker run -d --name prometheus --network prometheus -p 9090:9090 -v /home/ubuntu/prometheus:/etc/prometheus prom/prometheus

            EOF
  tags = {
    Name = "example_ec2_instance_1"
  }
}
resource "null_resource" "install_prometheus" {
  depends_on = [aws_instance.example_ec2_instance_1]

  provisioner "remote-exec" {
    inline = [
      "sleep 60",  # waiting for starting EC2 instance and Docker
      "curl localhost:9090",  # checking Prometheus
      "curl localhost:9100/metrics",  # checking Node-exporter
      "curl localhost:8080/metrics",  # checking Cadvizor-exporter
    ]

    connection {
      type = "ssh"
      user = "ubuntu"
      host = aws_instance.example_ec2_instance_1.public_ip
      private_key = file("example_key_pair.pem")  #SSH
    }
  }
}
resource "aws_instance" "example_ec2_instance_2" {
  ami = "hereAMI" # AMI ID
  instance_type = "t2.micro" # Type of instance
  key_name = "example_key_pair" # SSH key
  vpc_security_group_ids = [aws_security_group.example_sg.id]
  subnet_id = aws_subnet.example_public_subnet_2.id
  associate_public_ip_address = true
  user_data = <<-EOF
              #!/bin/bash
              # встановлення Docker та Docker Compose
              sudo apt-get update
              sudo apt-get -y install apt-transport-https ca-certificates curl gnupg-agent software-properties-common
              curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
              sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
              sudo apt-get update
              sudo apt-get -y install docker-ce docker-ce-cli containerd.io docker-compose

              # клонування репозиторію з конфігурацією
              git clone https://github.com/prometheus/node_exporter.git /home/ubuntu/node_exporter
              cd /home/ubuntu/node_exporter

              # запуск Node-exporter
              docker run -d --name node-exporter -p 9100:9100 -v "/proc:/host/proc" -v "/sys:/host/sys" -v "/:/rootfs" --net="host" prom/node-exporter

              # клонування репозиторію з конфігурацією
              git clone https://github.com/google/cadvisor.git /home/ubuntu/cadvisor
              cd /home/ubuntu/cadvisor

              # запуск Cadvizor-exporter
              docker run -d --name cadvisor-exporter -p 8080:8080 --volume=/var/run/docker.sock:/var/run/docker.sock google/cadvisor:latest -port=8080

              EOF
  tags = {
    Name = "example_ec2_instance_2"
  }
}
resource "null_resource" "install_node_exporter" {
  depends_on = [aws_instance.example_ec2_instance_2]

  provisioner "remote-exec" {
    inline = [
      "sleep 60",  # waiting for starting EC2 instance and Docker
      "curl localhost:9100/metrics",  # checking Node-exporter
      "curl localhost:8080/metrics",  # checking Cadvizor-exporter
    ]

    connection {
      type = "ssh"
      user = "ubuntu"
      host = aws_instance.example_ec2_instance_2.public_ip
      private_key = file("example_key_pair.pem")  # SSH
    }
  }
}