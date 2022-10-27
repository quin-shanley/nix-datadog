{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.datadog;

  ddConf = {
    skip_ssl_validation = false;
    run_path = "/var/run/datadog-agent";
    compliance_config.run_path = "/var/run/datadog-agent";
    logs_config.run_path = "/var/run/datadog-agent";
    confd_path = "/etc/datadog-agent/conf.d";
    additional_checksd = "/etc/datadog-agent/checks.d";
    use_dogstatsd = true;
    log_format_json = true;
    log_level = "warn";
    disable_file_logging = true;
  }
  // optionalAttrs (cfg.logLevel != null) { log_level = cfg.logLevel; }
  // optionalAttrs (cfg.hostname != null) { inherit (cfg) hostname; }
  // optionalAttrs (cfg.ddUrl != null) { dd_url = cfg.ddUrl; }
  // optionalAttrs (cfg.site != null) { site = cfg.site; }
  // optionalAttrs (cfg.tags != null) { tags = concatStringsSep ", " cfg.tags; }
  // optionalAttrs (cfg.enableLiveProcessCollection) { process_config = { enabled = "true"; }; }
  // optionalAttrs (cfg.enableTraceAgent) { apm_config = { enabled = true; }; }
  // cfg.extraConfig;

  # Generate Datadog configuration files for each configured checks.
  # This works because check configurations have predictable paths,
  # and because JSON is a valid subset of YAML.
  makeCheckConfigs = entries: mapAttrs'
    (name: conf: {
      name = "datadog-agent/conf.d/${name}.d/conf.yaml";
      value.source = pkgs.writeText "${name}-check-conf.yaml" (builtins.toJSON (builtins.removeAttrs conf [ "enable" ]));
    })
    (lib.filterAttrs (_: conf: conf.enable) entries);

  # Assemble all check configurations and the top-level agent
  # configuration.
  etcfiles = with pkgs; with builtins;
    {
      "datadog-agent/datadog.yaml" = {
        source = writeText "datadog.yaml" (toJSON ddConf);
      };
    } // makeCheckConfigs cfg.checks;

  # Apply the configured extraIntegrations to the provided agent
  # package. See the documentation of `dd-agent/integrations-core.nix`
  # for detailed information on this.
  datadogPkg = cfg.package;
in
{
  options.services.datadog = {
    enable = mkOption {
      description = lib.mdDoc ''
        Whether to enable the datadog-agent v7 monitoring service
      '';
      default = false;
      type = types.bool;
    };

    package = mkOption {
      default = pkgs.datadog;
      defaultText = literalExpression "pkgs.datadog";
      description = lib.mdDoc ''
        Which DataDog v7 agent package to use. Note that the provided
        package is expected to have an overridable `pythonPackages`-attribute
        which configures the Python environment with the Datadog
        checks.
      '';
      type = types.package;
    };

    apiKeyFile = mkOption {
      description = lib.mdDoc ''
        Path to a file containing the Datadog API key to associate the
        agent with your account.
      '';
      example = "/run/keys/datadog_api_key";
      type = types.path;
    };

    ddUrl = mkOption {
      description = lib.mdDoc ''
        Custom dd_url to configure the agent with. Useful if traffic to datadog
        needs to go through a proxy.
        Don't use this to point to another datadog site (EU) - use site instead.
      '';
      default = null;
      example = "http://haproxy.example.com:3834";
      type = types.nullOr types.str;
    };

    site = mkOption {
      description = lib.mdDoc ''
        The datadog site to point the agent towards.
        Set to datadoghq.eu to point it to their EU site.
      '';
      default = null;
      example = "datadoghq.eu";
      type = types.nullOr types.str;
    };

    tags = mkOption {
      description = lib.mdDoc "The tags to mark this Datadog agent";
      example = [ "test" "service" ];
      default = null;
      type = types.nullOr (types.listOf types.str);
    };

    hostname = mkOption {
      description = lib.mdDoc "The hostname to show in the Datadog dashboard (optional)";
      default = null;
      example = "mymachine.mydomain";
      type = types.nullOr types.str;
    };

    logLevel = mkOption {
      description = lib.mdDoc "Logging verbosity.";
      default = null;
      type = types.nullOr (types.enum [ "DEBUG" "INFO" "WARN" "ERROR" ]);
    };

    extraConfig = mkOption {
      default = { };
      type = types.attrs;
      description = lib.mdDoc ''
        Extra configuration options that will be merged into the
        main config file {file}`datadog.yaml`.
      '';
    };

    enableLiveProcessCollection = mkOption {
      description = lib.mdDoc ''
        Whether to enable the live process collection agent.
      '';
      default = false;
      type = types.bool;
    };

    enableTraceAgent = mkOption {
      description = lib.mdDoc ''
        Whether to enable the trace agent.
      '';
      default = false;
      type = types.bool;
    };

    checks = mkOption {
      description = lib.mdDoc ''
        Configuration for all Datadog checks. Keys of this attribute
        set will be used as the name of the check to create the
        appropriate configuration in `conf.d/$check.d/conf.yaml`.

        The configuration is converted into JSON from the plain Nix
        language configuration, meaning that you should write
        configuration adhering to Datadog's documentation - but in Nix
        language.

        Refer to the implementation of this module (specifically the
        definition of `defaultChecks`) for an example.

        Note: The 'disk' and 'network' check are configured in
        separate options because they exist by default. Attempting to
        override their configuration here will have no effect.
      '';

      example = {
        http_check = {
          init_config = null; # sic!
          instances = [
            {
              name = "some-service";
              url = "http://localhost:1337/healthz";
              tags = [ "some-service" ];
            }
          ];
        };
      };

      default = { };

      # sic! The structure of the values is up to the check, so we can
      # not usefully constrain the type further.
      type = with types; attrsOf (submodule {
        freeformType = anything;
        options.enable = mkOption {
          type = bool;
          default = true;
        };
      });
    };
  };
  config =
    let
      inherit (config.virtualisation) containerd cri-o docker podman;
    in
    {
      nixpkgs.overlays = [ (import ./overlay.nix) ];
    } // mkIf cfg.enable {
      services.datadog.checks =
        {
          disk = {
            instances = lib.mkDefault [{
              use_mount = "false";
              all_partitions = false;
              excluded_filesystems = [ "tmpfs" "nsfs" "overlay" "overlay2" ];
              excluded_mountpoint_re = "^(/var/lib/docker|/run/docker/netns)/";
            }];
          };

          network = {
            instances = lib.mkDefault [{
              collect_connection_state = false;
              excluded_interfaces = [ "lo" "lo0" ];
            }];
          };

          container.enable = lib.mkDefault (containerd.enable || cri-o.enable || docker.enable || podman.enable);
          container.instances = lib.mkDefault [{ }];
          containerd.enable = lib.mkDefault containerd.enable;
          containerd.instances = lib.mkDefault [{ }];
          cpu.instances = lib.mkDefault [{ }];
          cri.enable = lib.mkDefault cri-o.enable;
          cri.instances = lib.mkDefault [{ }];
          docker.enable = lib.mkDefault docker.enable;
          docker.instances = lib.mkDefault [{ }];
          io.instances = lib.mkDefault [{ }];
          load.instances = lib.mkDefault [{ }];
          memory.instances = lib.mkDefault [{ }];
          ntp.instances = lib.mkDefault [{ }];
          uptime.instances = lib.mkDefault [{ }];
        };

      environment.systemPackages = [ datadogPkg pkgs.sysstat pkgs.procps pkgs.iproute2 ];

      users.users.datadog = {
        description = "Datadog Agent User";
        uid = config.ids.uids.datadog;
        group = "datadog";
        extraGroups = lib.optionals config.virtualisation.docker.enable [ "docker" ];
      };

      users.groups.datadog.gid = config.ids.gids.datadog;

      systemd.services =
        let
          makeService = attrs: recursiveUpdate
            {
              path = [ datadogPkg pkgs.python pkgs.sysstat pkgs.procps pkgs.iproute2 ];
              wantedBy = [ "multi-user.target" ];
              serviceConfig = {
                User = "datadog";
                Group = "datadog";
                Restart = "always";
                RestartSec = 2;
              };
              restartTriggers = [ datadogPkg ] ++ map (x: x.source) (attrValues etcfiles);
            }
            attrs;
        in
        {
          datadog-agent = makeService {
            description = "Datadog agent monitor";
            preStart = ''
              chown -R datadog: /etc/datadog-agent /var/run/datadog-agent
              rm -f /etc/datadog-agent/auth_token
            '';
            script = ''
              export DD_API_KEY=$(head -n 1 ${cfg.apiKeyFile})
              exec ${datadogPkg}/bin/datadog-agent run --cfgpath /etc/datadog-agent
            '';
            serviceConfig.SyslogIdentifier = "datadog-agent";
            serviceConfig.PermissionsStartOnly = true;
            serviceConfig.RuntimeDirectory = "datadog-agent";
          };

          dd-jmxfetch = lib.mkIf (lib.hasAttr "jmx" cfg.checks) (makeService {
            description = "Datadog JMX Fetcher";
            path = [ datadogPkg pkgs.python pkgs.sysstat pkgs.procps pkgs.jdk ];
            serviceConfig.ExecStart = "${datadogPkg}/bin/dd-jmxfetch";
          });

          datadog-process-agent = lib.mkIf cfg.enableLiveProcessCollection (makeService {
            description = "Datadog Live Process Agent";
            path = [ ];
            script = ''
              export DD_API_KEY=$(head -n 1 ${cfg.apiKeyFile})
              ${datadogPkg}/bin/process-agent --cfgpath /etc/datadog-agent
            '';
            serviceConfig.SyslogIdentifier = "datadog-process-agent";
            serviceConfig.RuntimeDirectory = "datadog-agent";
          });

          datadog-trace-agent = lib.mkIf cfg.enableTraceAgent (makeService {
            description = "Datadog Trace Agent";
            path = [ ];
            script = ''
              export DD_API_KEY=$(head -n 1 ${cfg.apiKeyFile})
              ${datadogPkg}/bin/trace-agent --cfgpath /etc/datadog-agent
            '';
            serviceConfig.SyslogIdentifier = "datadog-trace-agent";
            serviceConfig.RuntimeDirectory = "datadog-agent";
          });
        };

      environment.etc = etcfiles;
    };
}
