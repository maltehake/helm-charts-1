{{- $root := . }}
- job_name: 'maia-exporters'
  scrape_interval: 1m
  scrape_timeout: 55s
  kubernetes_sd_configs:
    - role: endpoints
  relabel_configs:
    # filter by maia scrape annotation
    - action: keep
      source_labels: [__meta_kubernetes_service_annotation_maia_io_scrape]
      regex: true
    - action: keep
      source_labels: [__meta_kubernetes_pod_container_port_number, __meta_kubernetes_pod_container_port_name, __meta_kubernetes_service_annotation_prometheus_io_port]
      regex: (9102;.*;.*)|(.*;metrics;.*)|(.*;.*;\d+)
    # support existing prometheus annotations (same configuration as everywhere else)
    - source_labels: [__meta_kubernetes_service_annotation_prometheus_io_scheme]
      target_label: __scheme__
      regex: (https?)
    - source_labels: [__meta_kubernetes_service_annotation_maia_io_scheme]
      target_label: __scheme__
      regex: (https?)
    - source_labels: [__meta_kubernetes_service_annotation_prometheus_io_path]
      target_label: __metrics_path__
      regex: (.+)
    - source_labels: [__meta_kubernetes_service_annotation_maia_io_path]
      target_label: __metrics_path__
      regex: (.+)
    - source_labels: [__address__, __meta_kubernetes_service_annotation_prometheus_io_port]
      target_label: __address__
      regex: ([^:]+)(?::\d+)?;(\d+)
      replacement: $1:$2
    - source_labels: [__address__, __meta_kubernetes_service_annotation_maia_io_port]
      target_label: __address__
      regex: ([^:]+)(?::\d+)?;(\d+)
      replacement: $1:$2
    - action: labelmap
      regex: __meta_kubernetes_service_label_(.+)
    - source_labels: [__meta_kubernetes_namespace]
      target_label: kubernetes_namespace
    - source_labels: [__meta_kubernetes_service_name]
      target_label: kubernetes_name
    # support injection of custom parameters
    - action: labelmap
      replacement: __param_$1
      regex: __meta_kubernetes_service_annotation_maia_io_scrape_param_(.+)

  metric_relabel_configs:
    - action: drop
      source_labels: [vmware_name]
      regex: cc3test.*
    - action: labeldrop
      regex: "instance|job|alert_tier|alert_service"
    - source_labels: [ltmVirtualServStatName]
      target_label: project_id
      regex: /Project_(.*)/Project_.*
    - source_labels: [ltmVirtualServStatName]
      target_label: lb_id
      regex: /Project_.*/Project_(.*)

# expose tenant-specific metrics collected by kube-system monitoring
#
# FIXME: This is a cross-dependency between different chains of Prometheus
# instances which we want to avoid going forward. The pods supplying these
# metrics should be scraped by Maia directly.
#
# Since some of these metrics are already aggregated (e.g. the ones for
# Castellum), it may be necessary to add a maia-prometheus-collector that
# performs the aggregations before metrics are pulled into this Prometheus.
#- job_name: 'kube-system'
#  static_configs:
#    - targets: ['prometheus-collector.kube-monitoring:9090']
#  metric_relabel_configs:
#    - regex: "instance|job|kubernetes_namespace|kubernetes_pod_name|kubernetes_name|pod_template_hash|exported_instance|exported_job|type|name|component|app|system"
#      action: labeldrop
#  metrics_path: '/federate'
#  params:
#    'match[]':
#      # import any tenant-specific metric, except for those which already have been imported
#      - '{__name__=~"^castellum_aggregated_.+",project_id!=""}'
#      - '{__name__=~"^openstack_.+",project_id!=""}'
#      - '{__name__=~"^limes_(project|domain)_(quota|usage)"}'

- job_name: 'prometheus-openstack'
  scrape_interval: 1m
  scrape_timeout: 55s
  static_configs:
    - targets: ['prometheus-openstack.prometheus-openstack:9090']
  metric_relabel_configs:
    - regex: "instance|job|kubernetes_namespace|kubernetes_pod_name|kubernetes_name|pod_template_hash|exported_instance|exported_job|type|name|component|app|system|alert_tier|alert_service"
      action: labeldrop
  metrics_path: '/federate'
  params:
    'match[]':
      # import any tenant-specific metric, except for those which already have been imported
      - '{__name__=~"^castellum_aggregated_.+",project_id!=""}'
      - '{__name__=~"^openstack_.+",project_id!=""}'
      - '{__name__=~"^limes_(?:project|domain)_(?:quota|usage)$"}'
      - '{__name__=~"^limes_swift_.+",project_id!=""}'

- job_name: 'prometheus-infra-collector'
  scrape_interval: 1m
  scrape_timeout: 55s
  static_configs:
    - targets: ['prometheus-infra-collector.infra-monitoring:9090']
  metric_relabel_configs:
    - regex: "cluster|cluster_type|instance|job|kubernetes_namespace|kubernetes_pod_name|kubernetes_name|pod_template_hash|exported_instance|exported_job|type|name|component|app|system|thanos_cluster|thanos_cluster_type|thanos_region|alert_tier|alert_service"
      action: labeldrop
    - action: drop
      source_labels: [vmware_name]
      regex: cc3test.*
    - action: drop
      source_labels: [__name__]
      regex: netapp_volume_saved_.*
    - source_labels: [ltmVirtualServStatName]
      regex: /Common.*
      action: drop
    - source_labels: [ltmVirtualServStatName]
      target_label: project_id
      regex: /Project_(.*)/Project_.*
    - source_labels: [ltmVirtualServStatName]
      target_label: lb_id
      regex: /Project_.*/Project_(.*)
    - source_labels: [ltmVirtualServStatName]
      target_label: network_id
      regex: /net_(.+)_(.+)_(.+)_(.+)_(.+)/lb_.*
      replacement: $1-$2-$3-$4-$5
    - source_labels: [ltmVirtualServStatName]
      target_label: lb_id
      regex: /net_.*/lb_(.*)/listener_.*
    - source_labels: [ltmVirtualServStatName]
      target_label: listener_id
      regex: /net_.*/lb_.*/listener_(.*)
    - source_labels: [__name__]
      target_label: __name__
      regex: netapp_volume_(.*)
      replacement: openstack_manila_share_${1}

  metrics_path: '/federate'
  params:
    'match[]':
      # import any tenant-specific metric, except for those which already have been imported
      # filter for ltmVirtualServStatName to be present as it relabels into project_id. It gets enriched by "openstack/maia/aggregations/snmp-f5.rules with the openstack metric openstack_neutron_networks_projects"
      - '{__name__=~"^snmp_f5_.+", ltmVirtualServStatName!=""}'
      - '{__name__=~"^ssh_nat_limits_miss", project_id!=""}'
      - '{__name__=~"^ssh_nat_limits_use", project_id!=""}'
      - '{__name__=~"^snmp_asr_ifHC.+", project_id!=""}'
      - '{__name__=~"^netapp_capacity_.+", project_id!=""}'
      - '{__name__=~"^netapp_volume_.+", app="netapp-capacity-exporter-manila", project_id!=""}'
      - '{__name__=~"^openstack_manila_share_.+", project_id!=""}'

{{- if .Values.prometheus_vmware.enabled }}
{{- range $match := .Values.prometheus_vmware.matches }}
{{- $single_matchlist := splitList "_" $match }}
{{- $all_but_first := (slice $single_matchlist 1) | join "-" }}
- job_name: 'prometheus-vmware-vrops-{{ $all_but_first }}'
  scheme: http
  scrape_interval: "{{ $root.Values.prometheus_vmware.scrape_interval }}"
  scrape_timeout: "{{ $root.Values.prometheus_vmware.scrape_timeout }}"
  static_configs:
    - targets: ['prometheus-vmware.vmware-monitoring:9090']
  metric_relabel_configs:
    - source_labels: [__name__, project ]
      regex: '^vrops_virtualmachine_.+;(.+)'
      replacement: '$1'
      target_label: project_id
    - regex: 'project|collector|exported_job|instance|internal_name|prometheus|resource_uuid|thanos_cluster|thanos_cluster_type|vccluster|vcenter'
      action: labeldrop

  metrics_path: '/federate'
  params:
    'match[]':
      - '{{ "{" }}__name__=~"{{ $match }}", project!~"internal", vccluster!~".*management.*"{{ "}" }}'
{{- end }}
{{- end }}

{{- if .Values.neo.enabled }}
- job_name: 'prometheus-vmware-neo'
  scheme: http
  scrape_interval: "{{ .Values.prometheus_vmware.scrape_interval }}"
  scrape_timeout: "{{ .Values.prometheus_vmware.scrape_timeout }}"
  static_configs:
    - targets: ['prometheus-vmware.vmware-monitoring:9090']
  metric_relabel_configs:
    - source_labels: [__name__, project ]
      regex: '^vrops_virtualmachine_.+;(.+)'
      replacement: '$1'
      target_label: project_id
    - regex: 'project|collector|exported_job|instance|internal_name|prometheus|resource_uuid|thanos_cluster|thanos_cluster_type|vccluster|vcenter'
      action: labeldrop
    - source_labels: [__name__]
      target_label: domain_id
      regex: ^vrops_hostsystem_.+
      replacement: "{{ .Values.neo.domain_id  }}"

  metrics_path: '/federate'
  params:
    'match[]':
      - '{__name__=~"^vrops_hostsystem_cpu_model"}'
      - '{__name__=~"^vrops_hostsystem_cpu_sockets_number"}'
      - '{__name__=~"^vrops_hostsystem_cpu_usage_average_percentage"}'
      - '{__name__=~"^vrops_hostsystem_memory_ballooning_kilobytes"}'
      - '{__name__=~"^vrops_hostsystem_memory_contention_percentage"}'
{{- end }}

# For cronus reputation dashboard https://documentation.global.cloud.sap/docs/customer/services/email-service/email-serv-howto/email-howto-reputation/
{{- if .Values.cronus.enabled }}
- job_name: 'cronus-reputation-statistics'
  scheme: https
  scrape_interval: 1m
  scrape_timeout: 55s
  tls_config:
    cert_file: /etc/prometheus/secrets/prometheus-infra-sso-cert/sso.crt
    key_file: /etc/prometheus/secrets/prometheus-infra-sso-cert/sso.key
  static_configs:
    - targets:
      - "prometheus-infra.scaleout.{{ .Values.global.region }}.cloud.sap"
  metrics_path: '/federate'
  params:
    'match[]':
      - '{__name__="aws_ses_cronus_provider_bounce"}'
      - '{__name__="aws_ses_cronus_provider_complaint"}'
      - '{__name__="aws_ses_cronus_provider_delivery"}'
      - '{__name__="aws_ses_cronus_provider_reputation_bouncerate"}'
      - '{__name__="aws_ses_cronus_provider_reputation_complaintrate"}'
      - '{__name__="aws_ses_cronus_provider_send"}'
      - '{__name__="aws_ses_cronus_security_attributes_remaining_months_until_lease_ends"}'
      - '{__name__="aws_ses_cronus_suppressed_email_since_last_update_minutes"}'
      - '{__name__="aws_ses_cronus_identity_is_verified"}'
  metric_relabel_configs:
    - action: labeldrop
      regex: "exported_instance|exported_job|instance|job|tags|cluster|cluster_type|multicloud_id|alert_tier|alert_service"
{{ end }}
