# Configure terraform
terraform {
  required_version = "~> 1.0"
  required_providers {
    newrelic = {
      source  = "newrelic/newrelic"
    }
  }
}

variable "cluster_name" {
  type    = string
  description = "The name of the k8s cluster used to run the OpenTelemetry demo."
}

variable "account_id" {
  type = number
  description = "The account to apply the changes to."
}

# Configure the New Relic provider
provider "newrelic" {
  account_id = var.account_id
}

# Create a workload with all entities deployed to the demo cluster 
resource "newrelic_workload" "otel-demo-all-entities" {
    name = "OpenTelemetry Demo - All Entities"
    account_id = var.account_id

    entity_search_query {
      query = "tags.clusterName = '${var.cluster_name}' OR tags.k8s.cluster.name = '${var.cluster_name}' OR tags.displayName = '${var.cluster_name}'"
    }

    scope_account_ids =  [var.account_id]
}

# Create a workload with all APM and OTel instrumented services deployed to the demo cluster 
resource "newrelic_workload" "otel-demo-services" {
    name = "OpenTelemetry Demo - OTel Services"
    account_id = var.account_id

    entity_search_query {
      query = "tags.k8s.cluster.name = '${var.cluster_name}' AND (tags.instrumentation.provider = 'opentelemetry' OR tags.instrumentation.provider ='newRelic')"
    }

    scope_account_ids =  [var.account_id]
}

# Get the entity guid for the AdService OTel service
data "newrelic_entity" "adservice-entity" {
  name = "adservice"
  tag {
    key = "accountID"
    value = "${var.account_id}"
  }
}

# Get the entity guid for the ProductCatalog OTel service
data "newrelic_entity" "productcatalog-entity" {
  name = "productcatalogservice"
  tag {
    key = "accountID"
    value = "${var.account_id}"
  }
}

# Create a service level for AdService 
resource "newrelic_service_level" "adservice-service-level" {
    guid = data.newrelic_entity.adservice-entity.id
    name = "AdService Service Level"
    description = "Proportion of successful requests."

    events {
        account_id = var.account_id
        valid_events {
            from = "Span"
            where = "entity.guid='${data.newrelic_entity.adservice-entity.id}' AND (span.kind IN ('server', 'consumer') OR kind IN ('server', 'consumer'))"
        }
        bad_events {
            from = "Span"
            where = "entity.guid='${data.newrelic_entity.adservice-entity.id}' AND (span.kind IN ('server', 'consumer') OR kind IN ('server', 'consumer')) AND otel.status_code = 'ERROR'"
        }
    }

    objective {
        target = 99.25
        time_window {
            rolling {
                count = 1
                unit = "DAY"
            }
        }
    }
}

# Create a service level for AdService 
resource "newrelic_service_level" "productcatalog-service-level" {
    guid = data.newrelic_entity.productcatalog-entity.id
    name = "ProductCatalog Service Level"
    description = "Proportion of successful requests."

    events {
        account_id = var.account_id
        valid_events {
            from = "Span"
            where = "entity.guid='${data.newrelic_entity.productcatalog-entity.id}' AND (span.kind IN ('server', 'consumer') OR kind IN ('server', 'consumer'))"
        }
        bad_events {
            from = "Span"
            where = "entity.guid='${data.newrelic_entity.productcatalog-entity.id}' AND (span.kind IN ('server', 'consumer') OR kind IN ('server', 'consumer')) AND otel.status_code = 'ERROR'"
        }
    }

    objective {
        target = 99.25
        time_window {
            rolling {
                count = 1
                unit = "DAY"
            }
        }
    }
}

# Get the entity guid for the CartService OTel service
data "newrelic_entity" "cartservice-entity" {
  name = "cartservice"
  tag {
    key = "accountID"
    value = "${var.account_id}"
  }
}

# Create a service level for CartService 
resource "newrelic_service_level" "cartservice-service-level" {
    guid = data.newrelic_entity.cartservice-entity.id
    name = "CartService Service Level"
    description = "Proportion of successful requests."

    events {
        account_id = var.account_id
        valid_events {
            from = "Span"
            where = "entity.guid='${data.newrelic_entity.cartservice-entity.id}' AND (span.kind IN ('server', 'consumer') OR kind IN ('server', 'consumer'))"
        }
        bad_events {
            from = "Span"
            where = "entity.guid='${data.newrelic_entity.cartservice-entity.id}' AND (span.kind IN ('server', 'consumer') OR kind IN ('server', 'consumer')) AND otel.status_code = 'ERROR'"
        }
    }

    objective {
        target = 99.25
        time_window {
            rolling {
                count = 1
                unit = "DAY"
            }
        }
    }
}

# Create an alert policy to monitor service health of the OTel demo 
resource "newrelic_alert_policy" "oteldemo-service-health" {
  name = "OpenTelemetry Service Health"
  incident_preference = "PER_CONDITION" 
}

# Add an alert condition for OTel service health monitoring 
resource "newrelic_nrql_alert_condition" "otel-service-health" {
  account_id                     = var.account_id
  policy_id                      = newrelic_alert_policy.oteldemo-service-health.id
  type                           = "static"
  name                           = "otel-service-health"
  description                    = "Service has too many errors"
  enabled                        = true

  nrql {
    query = "FROM Span SELECT filter(count(*), WHERE otel.status_code = 'ERROR') / count(*) as 'Error rate for all errors' WHERE (span.kind LIKE 'server' OR span.kind LIKE 'consumer' OR kind LIKE 'server' OR kind LIKE 'consumer') FACET entity.name"
  }

  critical {
    operator              = "above"
    threshold             = 0.01
    threshold_duration    = 180
    threshold_occurrences = "ALL"
  }

  warning {
    operator              = "above"
    threshold             = 0.005
    threshold_duration    = 180
    threshold_occurrences = "ALL"
  }
}

# Add an alert condition for service levels 
resource "newrelic_nrql_alert_condition" "apm-service-levels" {
  account_id                     = var.account_id
  policy_id                      = newrelic_alert_policy.oteldemo-service-health.id
  type                           = "static"
  name                           = "apm-service-levels"
  description                    = "Service level objective is not met"
  enabled                        = true

  nrql {
    query = "FROM Metric SELECT sum(newrelic.sli.good) / sum(newrelic.sli.valid) as 'SLI' WHERE sli.guid IN ('${newrelic_service_level.adservice-service-level.sli_guid}','${newrelic_service_level.cartservice-service-level.sli_guid}') FACET sli.guid"
  }

  critical {
    operator              = "below"
    threshold             = 0.9925
    threshold_duration    = 60
    threshold_occurrences = "ALL"
  }
}

# Add OTel Collector Flow dashboard
resource "newrelic_one_dashboard_json" "otel_collector_flow_dashboard" {
     json = file("${path.module}/dashboards/otel_collector_data_flow.json")
}

resource "newrelic_one_dashboard_json" "replacer_dashboard" {
   json = replace(
  	replace(    # This changes the dashboard name
    	    file("./dashboards/otel_collector_data_flow.json"),
    	    "by Terraform"
    	    ,"renamed by Terraform"
  	),
	"999999999",  # This is the value in the source file
	"${var.account_id}"   # This is the value it will be changed to
	)
}

resource "newrelic_entity_tags" "otel_collector_flow_dashboard" {
	guid = newrelic_one_dashboard_json.otel_collector_flow_dashboard.guid
	tag {
    	     key    = "terraform"
    	     values = [true]
	}
}

output "otel_collector_flow_dashboard" {
      value = newrelic_one_dashboard_json.otel_collector_flow_dashboard.permalink
}
