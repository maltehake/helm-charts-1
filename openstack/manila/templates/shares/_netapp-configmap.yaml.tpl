{{- define "share_netapp_configmap" -}}
{{- $context := index . 0 -}}
{{- $share := index . 1 -}}
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ $context.Release.Name }}-share-netapp-{{$share.name}}
  labels:
    system: openstack
    type: configuration
    component: manila
data:
  backend.conf: |
{{ list $context $share | include "share_netapp_conf" | indent 4 }}
{{- end -}}
