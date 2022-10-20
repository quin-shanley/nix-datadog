{ lib
, stdenv
, datadogPackage

, python
, systemd
, rtloader

, withSystemd ? stdenv.isLinux
}:

{
  agent = datadogPackage.overrideAttrs ({ postInstall ? "", ... }: {
    pname = "datadog-agent";
    subPackages = [
      "cmd/agent"
    ];
    postInstall = postInstall + ''
      mv "$out/bin/agent" "$out/bin/datadog-agent"

      wrapProgram "$out/bin/datadog-agent" \
        --prefix LD_LIBRARY_PATH  : ${rtloader}/lib \
        --set PYTHONPATH "$out/${python.sitePackages}"'' + lib.optionalString withSystemd '' \
        --prefix LD_LIBRARY_PATH : ${lib.getLib systemd}/lib
    '';
  });

  dogstatsd = datadogPackage.overrideAttrs (_: {
    pname = "dogstatsd";
    subPackages = [
      "cmd/dogstatsd"
    ];
  });

  cluster-agent = datadogPackage.overrideAttrs (_: {
    pname = "datadog-cluster-agent";
    subPackages = [
      "cmd/cluster-agent"
    ];
  });

  iot-agent = datadogPackage.overrideAttrs (_: {
    pname = "datadog-iot-agent";
    subPackages = [
      "cmd/iot-agent"
    ];
  });

  process-agent = datadogPackage.overrideAttrs (_: {
    pname = "datadog-process-agent";
    subPackages = [
      "cmd/process-agent"
    ];
  });

  py-launcher = datadogPackage.overrideAttrs (_: {
    pname = "datadog-py-launcher";
    subPackages = [
      "cmd/py-launcher"
    ];
  });

  security-agent = datadogPackage.overrideAttrs (_: {
    pname = "datadog-security-agent";
    subPackages = [
      "cmd/security-agent"
    ];
  });

  trace-agent = datadogPackage.overrideAttrs (_: {
    pname = "datadog-trace-agent";
    subPackages = [
      "cmd/trace-agent"
    ];
  });
}
