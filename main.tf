provider "aws" {
    region = "us-east-1"
}

data "aws_vpc" "default" {
  default = true
}

data "aws_ami" "dask_base_cpu" {
    most_recent      = true

    filter {
        name   = "name"
        values = ["dask_base_cpu"]
    }

    filter {
        name   = "virtualization-type"
        values = ["hvm"]
    }

    owners     = ["self"]
}

resource "aws_security_group" "ssh_access" {
    name = "ssh_access"
    vpc_id = "${data.aws_vpc.default.id}"

    ingress {
        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"] // warning!
    }

    egress {
      from_port = 0
      to_port = 0
      protocol = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }
}

resource "aws_security_group" "dask_node_self" {
  name = "dask_node_self"
  vpc_id = "${data.aws_vpc.default.id}"

  ingress {
    protocol = "-1"
    from_port = 0
    to_port = 0
    self = true
  }
}


resource "aws_key_pair" "dask_node" {
  key_name   = "dask_node_key"
  public_key = "${file(".ssh/dask_node_key.pub")}"
}

resource "aws_instance" "scheduler" {
    ami                          = "${data.aws_ami.dask_base_cpu.id}"
    instance_type                = "m4.large"
    key_name                     = "${aws_key_pair.dask_node.key_name}"
    vpc_security_group_ids       = ["${aws_security_group.ssh_access.id}",
                                    "${aws_security_group.dask_node_self.id}"]
    associate_public_ip_address  = true

    tags {
        Name = "dask_scheduler"
    }

    connection {
        type        = "ssh"
        user        = "ubuntu"
        agent       = false
        timeout     = "2m"
        private_key = "${file(".ssh/dask_node_key")}"
    }

    provisioner "remote-exec" {
        inline = ["sudo docker run -dit --restart unless-stopped --net=host --name scheduler dask_base_cpu dask-scheduler --port 8786 --http-port 9786 --bokeh-port 8787"]
    }
}

resource "aws_spot_instance_request" "worker_cpu" {
    count                        = 3
    ami                          = "${data.aws_ami.dask_base_cpu.id}"
    spot_price                   = "0.033"
    instance_type                = "m4.large"
    key_name                     = "${aws_key_pair.dask_node.key_name}"
    vpc_security_group_ids       = ["${aws_security_group.ssh_access.id}",
                                    "${aws_security_group.dask_node_self.id}"]
    associate_public_ip_address  = true
    wait_for_fulfillment         = true

    tags {
        Name = "worker_cpu_${count.index}"
    }

    connection {
        type        = "ssh"
        user        = "ubuntu"
        agent       = false
        timeout     = "2m"
        private_key = "${file(".ssh/dask_node_key")}"
    }

    provisioner "remote-exec" {
        inline = ["sudo docker run -dit --net=host --name workers --restart unless-stopped dask_base_cpu dask-worker --reconnect --nprocs 2 ${aws_instance.scheduler.private_ip}:8786"]
    }
}

output "scheduler_ip" {
    value = "${aws_instance.scheduler.public_ip}"
}

output "worker_cpu_ips" {
    value = ["${aws_spot_instance_request.worker_cpu.*.public_ip}"]
}