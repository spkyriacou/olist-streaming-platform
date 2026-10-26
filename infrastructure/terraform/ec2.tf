data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-kernel-6.1-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

resource "aws_instance" "olist" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t3.large"

  subnet_id              = aws_subnet.olist.id
  vpc_security_group_ids = [aws_security_group.olist.id]

  associate_public_ip_address = true
  iam_instance_profile        = "olist-dev-ec2"

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 40
    encrypted             = true
    delete_on_termination = true
  }

  credit_specification {
    cpu_credits = "standard"
  }

  user_data = <<-EOF
    #!/bin/bash
    set -euxo pipefail
    systemctl enable --now amazon-ssm-agent
  EOF

  tags = {
    Name        = "olist-dev"
    Environment = "dev"
    Project     = "olist-streaming-platform"
  }

  depends_on = [
    aws_route_table_association.olist
  ]
}

output "ec2_instance_id" {
  description = "Olist development server instance ID"
  value       = aws_instance.olist.id
}