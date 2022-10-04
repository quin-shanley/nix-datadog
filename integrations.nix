{ lib
, callPackage
, fetchFromGitHub
, python
}:

let
  # Offically supported integrations
  integrations-core = fetchFromGitHub {
    owner = "DataDog";
    repo = "integrations-core";
    rev = "7.39.0";
    sha256 = "sha256-6exn8KgT4bYW2lgMngCF/n+/BBnY48OR11iesdHv1S8=";
  };

  # Community written integrations
  integrations-extras = fetchFromGitHub {
    owner = "DataDog";
    repo = "integrations-extras";
    rev = "2565b3975fe0347afb30d407b184a0b29c13d2d4";
    sha256 = "sha256-doz5UfZtfbM2R2uatWWx7Va4R/iOOWA1yMRSfq/CEns=";
  };

  # Builder for Datadog integrations.
  buildIntegration = name: { format ? "pyproject", src, sourceRoot ? "source/${name}", ... }@attrs:
    python.pkgs.buildPythonPackage (attrs // {
      name = "datadog-integrations-${name}";
      inherit format src sourceRoot;
      doCheck = false;
    });

  # The base library for Datadog checks.
  checks-base = buildIntegration "checks_base" {
    format = "setuptools";
    src = integrations-core;
    sourceRoot = "source/datadog_checks_base";
    propagatedBuildInputs = with python.pkgs; [
      cachetools
      cryptography
      hatchling
      immutables
      jellyfish
      prometheus-client
      protobuf
      pydantic
      python-dateutil
      pyyaml
      requests
      requests-toolbelt
      requests-unixsocket
      simplejson
      uptime
      wrapt
    ];
  };

  # Builder for core integrations.
  buildCore = name: { propagatedBuildInputs ? [], ... }@attrs: buildIntegration name (lib.mergeAttrs attrs {
    src = integrations-core;
    propagatedBuildInputs = [ checks-base ] ++ propagatedBuildInputs;
    meta = with lib; {
      description = "An officially supported integration for the Datadog Agent.";
      homepage    = "https://github.com/DataDog/integrations-core/tree/master/${name}";
      license     = licenses.bsd3;
      maintainers = with maintainers; [ thoughtpolice domenkozar rvl viraptor ];
    };
  });

  # Builder for third-party/extras integrations.
  buildExtras = name: { propagatedBuildInputs ? [], ... }@attrs: buildIntegration name (lib.mergeAttrs attrs {
    src = integrations-extras;
    propagatedBuildInputs = [ checks-base ] ++ propagatedBuildInputs;
    meta = with lib; {
      description = "A community written integration for the Datadog Agent.";
      homepage    = "https://github.com/DataDog/integrations-extras/tree/master/${name}";
      license     = licenses.bsd3;
      maintainers = with maintainers; [ thoughtpolice domenkozar rvl viraptor ];
    };
  });
in

rec {
  inherit checks-base;

  # Official integrations
  active-directory = buildCore "active_directory" { };
  activemq = buildCore "activemq" { };
  activemq-xml = buildCore "activemq_xml" { };
  aerospike = buildCore "aerospike" { };
  airflow = buildCore "airflow" { };
  amazon-msk = buildCore "amazon_msk" { };
  ambari = buildCore "ambari" { };
  apache = buildCore "apache" { };
  arangodb = buildCore "arangodb" { };
  aspdotnet = buildCore "aspdotnet" { };
  avi-vantage = buildCore "avi_vantage" { };
  azure-iot-edge = buildCore "azure_iot_edge" { };
  boundary = buildCore "boundary" { };
  btrfs = buildCore "btrfs" { };
  cacti = buildCore "cacti" { };
  calico = buildCore "calico" { };
  cassandra = buildCore "cassandra" { };
  cassandra-nodetool = buildCore "cassandra_nodetool" { };
  ceph = buildCore "ceph" { };
  cilium = buildCore "cilium" { };
  cisco-aci = buildCore "cisco_aci" { };
  citrix-hypervisor = buildCore "citrix_hypervisor" { };
  clickhouse = buildCore "clickhouse" { };
  cloud-foundry-api = buildCore "cloud_foundry_api" { };
  cockroachdb = buildCore "cockroachdb" { };
  confluent-platform = buildCore "confluent_platform" { };
  consul = buildCore "consul" { };
  coredns = buildCore "coredns" { };
  couch = buildCore "couch" { };
  couchbase = buildCore "couchbase" { };
  crio = buildCore "crio" { };
  datadog-cluster-agent = buildCore "datadog_cluster_agent" { };
  directory = buildCore "directory" { };
  disk = buildCore "disk" { };
  dns-check = buildCore "dns_check" { };
  dotnetclr = buildCore "dotnetclr" { };
  druid = buildCore "druid" { };
  ecs-fargate = buildCore "ecs_fargate" { };
  eks-fargate = buildCore "eks_fargate" { };
  elastic = buildCore "elastic" { };
  envoy = buildCore "envoy" { };
  etcd = buildCore "etcd" { };
  exchange-server = buildCore "exchange_server" { };
  external-dns = buildCore "external_dns" { };
  flink = buildCore "flink" { };
  fluentd = buildCore "fluentd" { };
  foundationdb = buildCore "foundationdb" { };
  gearmand = buildCore "gearmand" { };
  gitlab = buildCore "gitlab" { };
  gitlab-runner = buildCore "gitlab_runner" { };
  glusterfs = buildCore "glusterfs" { };
  go-expvar = buildCore "go_expvar" { };
  gunicorn = buildCore "gunicorn" { };
  haproxy = buildCore "haproxy" { };
  harbor = buildCore "harbor" { };
  hazelcast = buildCore "hazelcast" { };
  hdfs-datanode = buildCore "hdfs_datanode" { };
  hdfs-namenode = buildCore "hdfs_namenode" { };
  hive = buildCore "hive" { };
  hivemq = buildCore "hivemq" { };
  http-check = buildCore "http_check" { };
  hudi = buildCore "hudi" { };
  hyperv = buildCore "hyperv" { };
  ibm-ace = buildCore "ibm_ace" { };
  ibm-db-2 = buildCore "ibm_db2" { };
  ibm-i = buildCore "ibm_i" { };
  ibm-mq = buildCore "ibm_mq" { };
  ibm-was = buildCore "ibm_was" { };
  ignite = buildCore "ignite" { };
  iis = buildCore "iis" { };
  istio = buildCore "istio" { };
  jboss-wildfly = buildCore "jboss_wildfly" { };
  journald = buildCore "journald" { };
  kafka = buildCore "kafka" { };
  kafka-consumer = buildCore "kafka_consumer" { };
  kong = buildCore "kong" { };
  kube-apiserver-metrics = buildCore "kube_apiserver_metrics" { };
  kube-controller-manager = buildCore "kube_controller_manager" { };
  kube-dns = buildCore "kube_dns" { };
  kube-metrics-server = buildCore "kube_metrics_server" { };
  kube-proxy = buildCore "kube_proxy" { };
  kube-scheduler = buildCore "kube_scheduler" { };
  kubelet = buildCore "kubelet" { };
  kubernetes-state = buildCore "kubernetes_state" { };
  kyototycoon = buildCore "kyototycoon" { };
  lighttpd = buildCore "lighttpd" { };
  linkerd = buildCore "linkerd" { };
  linux-proc-extras = buildCore "linux_proc_extras" { };
  mapr = buildCore "mapr" { };
  mapreduce = buildCore "mapreduce" { };
  marathon = buildCore "marathon" { };
  marklogic = buildCore "marklogic" { };
  mcache = buildCore "mcache" { };
  mesos-master = buildCore "mesos_master" { };
  mesos-slave = buildCore "mesos_slave" { };
  mongo = buildCore "mongo" { };
  mysql = buildCore "mysql" { };
  nagios = buildCore "nagios" { };
  network = buildCore "network" { };
  nfsstat = buildCore "nfsstat" { };
  nginx = buildCore "nginx" { };
  nginx-ingress-controller = buildCore "nginx_ingress_controller" { };
  openldap = buildCore "openldap" { };
  openmetrics = buildCore "openmetrics" { };
  openstack = buildCore "openstack" { };
  openstack-controller = buildCore "openstack_controller" { };
  oracle = buildCore "oracle" { };
  pan-firewall = buildCore "pan_firewall" { };
  pdh-check = buildCore "pdh_check" { };
  pgbouncer = buildCore "pgbouncer" { };
  php-fpm = buildCore "php_fpm" { };
  postfix = buildCore "postfix" { };
  postgres = buildCore "postgres" { };
  powerdns-recursor = buildCore "powerdns_recursor" { };
  presto = buildCore "presto" { };
  process = buildCore "process" { };
  prometheus = buildCore "prometheus" { };
  proxysql = buildCore "proxysql" { };
  pulsar = buildCore "pulsar" { };
  rabbitmq = buildCore "rabbitmq" { };
  redisdb = buildCore "redisdb" { };
  rethinkdb = buildCore "rethinkdb" { };
  riak = buildCore "riak" { };
  riakcs = buildCore "riakcs" { };
  sap-hana = buildCore "sap_hana" { };
  scylla = buildCore "scylla" { };
  sidekiq = buildCore "sidekiq" { };
  silk = buildCore "silk" { };
  singlestore = buildCore "singlestore" { };
  snmp = buildCore "snmp" { };
  snowflake = buildCore "snowflake" { };
  solr = buildCore "solr" { };
  sonarqube = buildCore "sonarqube" { };
  spark = buildCore "spark" { };
  sqlserver = buildCore "sqlserver" { };
  squid = buildCore "squid" { };
  ssh-check = buildCore "ssh_check" { };
  statsd = buildCore "statsd" { };
  supervisord = buildCore "supervisord" { };
  system-core = buildCore "system_core" { };
  system-swap = buildCore "system_swap" { };
  tcp-check = buildCore "tcp_check" { };
  teamcity = buildCore "teamcity" { };
  tenable = buildCore "tenable" { };
  teradata = buildCore "teradata" { };
  tls = buildCore "tls" { };
  tomcat = buildCore "tomcat" { };
  traffic-server = buildCore "traffic_server" { };
  twemproxy = buildCore "twemproxy" { };
  twistlock = buildCore "twistlock" { };
  varnish = buildCore "varnish" { };
  vault = buildCore "vault" { };
  vertica = buildCore "vertica" { };
  voltdb = buildCore "voltdb" { };
  vsphere = buildCore "vsphere" { };
  weblogic = buildCore "weblogic" { };
  win-32-event-log = buildCore "win32_event_log" { };
  windows-performance-counters = buildCore "windows_performance_counters" { };
  windows-service = buildCore "windows_service" { };
  wmi-check = buildCore "wmi_check" { };
  yarn = buildCore "yarn" { };
  zk = buildCore "zk" { };

  # Third-party integrations
  aqua = buildExtras "aqua" {};
  aws-pricing = buildExtras "aws_pricing" {};
  bind-9 = buildExtras "bind9" {};
  cert-manager = buildExtras "cert_manager" {};
  cfssl = buildExtras "cfssl" {};
  cloudsmith = buildExtras "cloudsmith" {};
  cyral = buildExtras "cyral" {};
  eventstore = buildExtras "eventstore" {};
  exim = buildExtras "exim" {};
  filebeat = buildExtras "filebeat" {};
  fluentbit = buildExtras "fluentbit" {};
  flume = buildExtras "flume" {};
  fluxcd = buildExtras "fluxcd" {};
  gatekeeper = buildExtras "gatekeeper" {};
  gitea = buildExtras "gitea" {};
  gnatsd = buildExtras "gnatsd" {};
  gnatsd-streaming = buildExtras "gnatsd_streaming" {};
  grpc-check = buildExtras "grpc_check" {};
  hbase-master = buildExtras "hbase_master" {};
  hbase-regionserver = buildExtras "hbase_regionserver" {};
  jfrog-platform = buildExtras "jfrog_platform" {};
  kernelcare = buildExtras "kernelcare" {};
  lighthouse = buildExtras "lighthouse" {};
  logstash = buildExtras "logstash" {};
  neo-4-j = buildExtras "neo4j" {};
  neutrona = buildExtras "neutrona" {};
  nextcloud = buildExtras "nextcloud" {};
  nn-sdwan = buildExtras "nn_sdwan" { format = "setuptools"; };
  ns-1 = buildExtras "ns1" {};
  nvml = buildExtras "nvml" {};
  octoprint = buildExtras "octoprint" {};
  open-policy-agent = buildExtras "open_policy_agent" {};
  php-apcu = buildExtras "php_apcu" {};
  php-opcache = buildExtras "php_opcache" {};
  pihole = buildExtras "pihole" {};
  ping = buildExtras "ping" {};
  portworx = buildExtras "portworx" {};
  puma = buildExtras "puma" {};
  purefa = buildExtras "purefa" {};
  purefb = buildExtras "purefb" {};
  reboot-required = buildExtras "reboot_required" {};
  redis-sentinel = buildExtras "redis_sentinel" {};
  redisenterprise = buildExtras "redisenterprise" {};
  redpanda = buildExtras "redpanda" {};
  resin = buildExtras "resin" {};
  riak-repl = buildExtras "riak_repl" {};
  sendmail = buildExtras "sendmail" {};
  snmpwalk = buildExtras "snmpwalk" {};
  sortdb = buildExtras "sortdb" {};
  speedtest = buildExtras "speedtest" {};
  stardog = buildExtras "stardog" {};
  storm = buildExtras "storm" {};
  syncthing = buildExtras "syncthing" {};
  tidb = buildExtras "tidb" {};
  traefik = buildExtras "traefik" {};
  trino = buildExtras "trino" {};
  unbound = buildExtras "unbound" {};
  unifi-console = buildExtras "unifi_console" {};
  upsc = buildExtras "upsc" {};
  vespa = buildExtras "vespa" {};
  zabbix = buildExtras "zabbix" {};
}
