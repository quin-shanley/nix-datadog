{ lib
, stdenv
, datadogPackage

, python
, systemd
, rtloader

, withSystemd ? stdenv.isLinux
}:

# adapted from https://github.com/DataDog/datadog-agent/blob/390540c8241f68ccdd65ff0451041b683f4c46fb/tasks/build_tags.py
let
  # agent_tags lists the tags needed when building the agent.
  agentTags = [
    "apm"
    "consul"
    "containerd"
    "cri"
    "docker"
    "ec2"
    "etcd"
    "gce"
    "jetson"
    "jmx"
    "kubeapiserver"
    "kubelet"
    "netcgo"
    "orchestrator"
    "otlp"
    "podman"
    "process"
    "python"
    "secrets"
    "systemd"
    "zk"
    "zlib"
  ];

  # clusterAgentTags lists the tags needed when building the cluster-agent
  clusterAgentTags = [ "clusterchecks" "kubeapiserver" "orchestrator" "secrets" "zlib" "ec2" "gce" ];

  # dogstatsdTags lists the tags needed when building dogstatsd
  dogstatsdTags = [ "containerd" "docker" "kubelet" "podman" "secrets" "zlib" ];

  # iotAgentTags lists the tags needed when building the IoT agent
  iotAgentTags = [ "jetson" "otlp" "systemd" "zlib" ];

  # processAgentTags lists the tags necessary to build the process-agent
  processAgentTags = lib.subtractLists [ "otlp" "python" ] (agentTags ++ [
    "clusterchecks"
    "fargateprocess"
    "orchestrator"
  ]);

  # securityAgentTags lists the tags necessary to build the security agent
  securityAgentTags = [ "netcgo" "secrets" "docker" "containerd" "kubeapiserver" "kubelet" "podman" "zlib" ];

  # systemProbeTags lists the tags necessary to build system-probe
  systemProbeTags = lib.subtractLists [ "python" ] (agentTags ++ [
    "clusterchecks"
    "linux_bpf"
    "npm"
  ]);

  # traceAgentTags lists the tags that have to be added when the trace-agent
  traceAgentTags = [ "docker" "containerd" "kubeapiserver" "kubelet" "otlp" "netcgo" "podman" "secrets" ];

  # List of tags to remove on the current system
  excludedTags = []
    ++ lib.optionals (!stdenv.isLinux)  [ "netcgo" "systemd" "jetson" "linux_bpf" "podman" ]
    ++ lib.optionals stdenv.isDarwin [ "docker" "containerd" "cri" ];
in
{
  agent = datadogPackage.overrideAttrs ({ postInstall ? "", ... }: {
    pname = "datadog-agent";
    subPackages = [
      "cmd/agent"
    ];
    postInstall = postInstall + ''
      mv "$out/bin/agent" "$out/bin/datadog-agent"
    '';
    tags = lib.subtractLists excludedTags agentTags;
  });

  dogstatsd = datadogPackage.overrideAttrs (_: {
    pname = "dogstatsd";
    subPackages = [
      "cmd/dogstatsd"
    ];
    tags = lib.subtractLists excludedTags dogstatsdTags;
  });

  cluster-agent = datadogPackage.overrideAttrs (_: {
    pname = "datadog-cluster-agent";
    subPackages = [
      "cmd/cluster-agent"
    ];
    tags = lib.subtractLists excludedTags clusterAgentTags;
  });

  iot-agent = datadogPackage.overrideAttrs (_: {
    pname = "datadog-iot-agent";
    subPackages = [
      "cmd/iot-agent"
    ];
    tags = lib.subtractLists excludedTags iotAgentTags;
  });

  process-agent = datadogPackage.overrideAttrs (_: {
    pname = "datadog-process-agent";
    subPackages = [
      "cmd/process-agent"
    ];
    tags = lib.subtractLists excludedTags processAgentTags;
  });

  security-agent = datadogPackage.overrideAttrs (_: {
    pname = "datadog-security-agent";
    subPackages = [
      "cmd/security-agent"
    ];
    tags = lib.subtractLists excludedTags securityAgentTags;
  });

  trace-agent = datadogPackage.overrideAttrs (_: {
    pname = "datadog-trace-agent";
    subPackages = [
      "cmd/trace-agent"
    ];
    tags = lib.subtractLists excludedTags traceAgentTags;
  });
}
