// All hostnames given will be included in the SAN field of the certificate,
// but the ACM API automatically includes the domain_name in the SAN field of the cert,
// and *excludes* it in the response to acm.DescribeCertificate, so we split them here.
locals {
  common_name               = "${var.hostnames[0]}"
  subject_alternative_names = "${slice(var.hostnames, 1, length(var.hostnames))}"
}

// For generating the DNS records, we convert hostnames into their zone name.
// This makes assumptions about the zone layout
locals {
  host_to_zone_regex = "/^(?:.*\\.)?([^.]+\\.[^.]+)$/"
}

data "aws_route53_zone" "zone" {
  count        = "${length(var.hostnames)}"
  name         = "${replace(var.hostnames[count.index], "${local.host_to_zone_regex}", "$1")}"
  private_zone = false
}

resource "aws_acm_certificate" "certificate" {
  domain_name               = "${local.common_name}"
  subject_alternative_names = "${local.subject_alterative_names}"
  validation_method         = "DNS"
}

resource "aws_route53_record" "validation" {
  count   = "${length(var.hostnames)}"
  zone_id = "${data.aws_route53_zone.zone.*.id[count.index]}"

  name    = "${lookup(aws_acm_certificate.certificate.domain_validation_options[count.index], "resource_record_name")}"
  type    = "${lookup(aws_acm_certificate.certificate.domain_validation_options[count.index], "resource_record_type")}"
  records = ["${lookup(aws_acm_certificate.certificate.domain_validation_options[count.index], "resource_record_value")}"]
  ttl     = 60
}

resource "aws_acm_certificate_validation" "certificate" {
  certificate_arn         = "${aws_acm_certificate.certificate.arn}"
  validation_record_fqdns = ["${aws_route53_record.validation.*.fqdn}"]
}
