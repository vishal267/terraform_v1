
provider "aws" {
  region = "us-east-1"
}

# ---------------------------------------------------------------------------------------------------------------------
# GET THE LIST OF AVAILABILITY ZONES IN THE CURRENT REGION
# Every AWS accout has slightly different availability zones in each region. For example, one account might have
# us-east-1a, us-east-1b, and us-east-1c, while another will have us-east-1a, us-east-1b, and us-east-1d. This resource
# queries AWS to fetch the list for the current account and region.
# ---------------------------------------------------------------------------------------------------------------------

data "aws_availability_zones" "all" {}
data "aws_availability_zones" "available" {}


#data "aws_route53_zone" "zone" {
#  name = "${var.route53_hosted_zone_name}"
#}


# NETWORKING #
resource "aws_vpc" "vpc" {
  cidr_block = "${var.network_base_cidr}"
}

resource "aws_internet_gateway" "igw" {
  vpc_id = "${aws_vpc.vpc.id}"
}

resource "aws_subnet" "subnet1" {
  cidr_block              = "${var.subnet1_address_space}"
  vpc_id                  = "${aws_vpc.vpc.id}"
  map_public_ip_on_launch = "true"
  availability_zone       = "${data.aws_availability_zones.available.names[0]}"
}

resource "aws_subnet" "subnet2" {
  cidr_block              = "${var.subnet2_address_space}"
  vpc_id                  = "${aws_vpc.vpc.id}"
  map_public_ip_on_launch = "true"
  availability_zone       = "${data.aws_availability_zones.available.names[1]}"
}

# ROUTING #
resource "aws_route_table" "rtb" {
  vpc_id = "${aws_vpc.vpc.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.igw.id}"
  }
}

resource "aws_route_table_association" "rta-subnet1" {
  subnet_id      = "${aws_subnet.subnet1.id}"
  route_table_id = "${aws_route_table.rtb.id}"
}

resource "aws_route_table_association" "rta-subnet2" {
  subnet_id      = "${aws_subnet.subnet2.id}"
  route_table_id = "${aws_route_table.rtb.id}"
}



# ---------------------------------------------------------------------------------------------------------------------
# CREATE THE AUTO SCALING GROUP
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_autoscaling_group" "example" {
  launch_configuration = "${aws_launch_configuration.example.id}"
  availability_zones = ["${data.aws_availability_zones.all.names}"]

  min_size = "${var.asg_min_size}"
  max_size = "${var.asg_max_size}"

  load_balancers = ["${aws_lb.example.name}"]
  health_check_type = "ELB"

#  tags{
#    key = "Name"
#    value = "terraform-asg-example"
#   propagate_at_launch = true
#  }
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE A LAUNCH CONFIGURATION THAT DEFINES EACH EC2 INSTANCE IN THE ASG
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_launch_configuration" "example" {
  # Ubuntu Server 14.04 LTS (HVM), SSD Volume Type in us-east-1
  image_id = "ami-2d39803a"
  instance_type = "t2.micro"
  security_groups = ["${aws_security_group.instance.id}"]

  user_data = <<-EOF
              #!/bin/bash
              echo "Hello, World" > index.html
              nohup busybox httpd -f -p "${var.server_port}" &
              EOF

  # Important note: whenever using a launch configuration with an auto scaling group, you must set
  # create_before_destroy = true. However, as soon as you set create_before_destroy = true in one resource, you must
  # also set it in every resource that it depends on, or you'll get an error about cyclic dependencies (especially when
  # removing resources). For more info, see:
  #
  # https://www.terraform.io/docs/providers/aws/r/launch_configuration.html
  # https://terraform.io/docs/configuration/resources.html
  lifecycle {
    create_before_destroy = true
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE THE SECURITY GROUP THAT'S APPLIED TO EACH EC2 INSTANCE IN THE ASG
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_security_group" "instance" {
  name = "terraform-example-instance"

  # Inbound HTTP from anywhere
  ingress {
    from_port = "${var.server_port}"
    to_port = "${var.server_port}"
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # aws_launch_configuration.launch_configuration in this module sets create_before_destroy to true, which means
  # everything it depends on, including this resource, must set it as well, or you'll get cyclic dependency errors
  # when you try to do a terraform destroy.
  lifecycle {
    create_before_destroy = true
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE AN ALB TO ROUTE TRAFFIC ACROSS THE AUTO SCALING GROUP
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_lb" "example" {
  name = "terraform-asg-example"
  subnets         = ["${aws_subnet.subnet1.id}", "${aws_subnet.subnet2.id}"]
  internal           = false
  load_balancer_type = "application"
  security_groups = ["${aws_security_group.elb.id}"]
#  subnets            = ["${aws_subnet.public.*.id}"]

  enable_deletion_protection = true

}
  #tags {
   # Environment = "production"
  #}


#Create Target Group - 

resource "aws_alb_target_group" "group" {
  name     = "terraform-example-alb-target"
  port     = 80
  protocol = "HTTP"
  vpc_id   = "${aws_vpc.vpc.id}"
  stickiness {
    type = "lb_cookie"
  }
  # Alter the destination of the health check to be the login page.
  health_check {
    path = "/login"
    port = 80
  }
}

#listener - application load balancer listernes 
#HTTP Listeners

resource "aws_alb_listener" "listener_http" {
  load_balancer_arn = "${aws_lb.example.arn}"
  port              = "80"
  protocol          = "HTTP"

  default_action {
    target_group_arn = "${aws_alb_target_group.group.arn}"
    type             = "forward"
  }
}


#HTTPS Listeners 

resource "aws_alb_listener" "listener_https" {
  load_balancer_arn = "${aws_lb.example.arn}"
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = "${var.certificate_arn}"
  default_action {
    target_group_arn = "${aws_alb_target_group.group.arn}"
    type             = "forward"
  }
}


#resource "aws_route53_record" "terraform" {
#  zone_id = "${data.aws_route53_zone.zone.zone_id}"
#  name    = "terraform.${var.route53_hosted_zone_name}"
#  type    = "A"
#  alias {
#    name                   = "${aws_alb.alb.dns_name}"
#    zone_id                = "${aws_alb.alb.zone_id}"
#    evaluate_target_health = true
#  }
#}



#resource "aws_elb" "example" {
#  name = "terraform-asg-example"
#  subnets         = ["${aws_subnet.subnet1.id}", "${aws_subnet.subnet2.id}"]
#  security_groups = ["${aws_security_group.elb-sg.id}"]

#  security_groups = ["${aws_security_group.elb.id}"]
#  availability_zones = ["${data.aws_availability_zones.all.names}"]

#  health_check {
#    healthy_threshold = 2
#    unhealthy_threshold = 2
#    timeout = 3
#    interval = 30
#    target = "HTTP:${var.server_port}/"
#  }

  # This adds a listener for incoming HTTP requests.
#  listener {
#    lb_port = 80
#    lb_protocol = "http"
#    instance_port = "${var.server_port}"
#    instance_protocol = "http"
#  }
#}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE A SECURITY GROUP THAT CONTROLS WHAT TRAFFIC AN GO IN AND OUT OF THE ELB
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_security_group" "elb" {
  name = "terraform-example-elb"

  # Allow all outbound
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Inbound HTTP from anywhere
  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
