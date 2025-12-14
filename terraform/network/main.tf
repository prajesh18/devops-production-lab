resource "aws_vpc" "my_vpc" {
  cidr_block           = var.cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = var.vpc_name
    Environment = var.environment
  }
}

output "my_vpc_id" {
  value = aws_vpc.my_vpc.id
}

# ---------- Public Subnets ----------
resource "aws_subnet" "public_subnet" {
  count                   = length(var.aws_azs)
  vpc_id                  = aws_vpc.my_vpc.id
  availability_zone       = var.aws_azs[count.index]
  cidr_block              = var.public_cidr[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name        = "${var.environment}-public-${count.index + 1}"
    Environment = var.environment
  }
}

# ---------- Private Subnets ----------
resource "aws_subnet" "private_subnet" {
  count             = length(var.aws_azs)
  vpc_id            = aws_vpc.my_vpc.id
  availability_zone = var.aws_azs[count.index]
  cidr_block        = var.private_cidr[count.index]

  tags = {
    Name        = "${var.environment}-private-${count.index + 1}"
    Environment = var.environment
  }
}
