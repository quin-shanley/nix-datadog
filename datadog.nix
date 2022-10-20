{ lib
, stdenv
, symlinkJoin

, buildGoModule
, callPackage
, fetchFromGitHub
, hostname
, makeWrapper
, pkg-config
, python
, systemd

, withSystemd ? stdenv.isLinux
}:

let
  owner = "DataDog";
  repo = "datadog-agent";
  version = "7.38.1";
  payloadVersion = "4.78.0"; # keep this in sync with github.com/DataDog/agent-payload dependency
  sha256 = "sha256-bG8wsSQvZcG4/Th6mWVdVX9vpeYBZx8FxwdYXpIdXnU=";
  vendorSha256 = "sha256-bGDf48wFa32hURZfGN5pCMmslC3PeLNayKcl5cfjq9M=";

  src = fetchFromGitHub {
    inherit owner repo sha256;
    rev = version;
  };

  mkBuildEnv =
    prevAttrs:
    prevPackagesFns:
    prevIntegrationsFns:
    { packages ? { enabled ? [ ], all, ... }: enabled
    , integrations ? { enabled ? [ ], all, ... }: enabled
    , ...
    }@attrs:
    let
      allIntegrations = callPackage ./integrations.nix {
        inherit python;
      };
      allPackages = callPackage ./packages.nix {
        inherit datadogPackage rtloader withSystemd;
        python = pythonWithIntegrations;
      };

      thisAttrs = { extraTags = [ ]; } // prevAttrs // attrs;

      thisIntegrationsFns = prevIntegrationsFns ++ [ integrations ];
      thisIntegrations = [ allIntegrations.checks-base ] ++ builtins.foldl'
        (enabled: f: f {
          inherit enabled;
          all = allIntegrations;
        }) [ ]
        thisIntegrationsFns;

      thisPackagesFns = prevPackagesFns ++ [ packages ];
      thisPackages = builtins.foldl'
        (enabled: f: f {
          inherit enabled;
          all = allPackages;
        }) [ ]
        thisPackagesFns;

      buildEnv = mkBuildEnv thisAttrs thisPackagesFns thisIntegrationsFns;

      pythonWithIntegrations = python.withPackages (_: thisIntegrations);
      rtloader = callPackage ./rtloader.nix {
        inherit src version;
        python = pythonWithIntegrations;
      };

      datadogPackage = buildGoModule rec {
        pname = "datadog";
        inherit src vendorSha256 version;

        doCheck = false;

        nativeBuildInputs = [ pkg-config makeWrapper ];
        buildInputs = [ rtloader ]
          ++ lib.optionals withSystemd [ systemd ];

        PKG_CONFIG_PATH = "${pythonWithIntegrations}/lib/pkgconfig";

        tags = [ "ec2" "python" "process" "log" "secrets" ] ++ lib.optionals withSystemd [ "systemd" ] ++ thisAttrs.extraTags;

        ldflags = let path = "github.com/${owner}/${repo}"; in [
          "-X ${path}/pkg/version.Commit=${src.rev}"
          "-X ${path}/pkg/version.AgentVersion=${version}"
          "-X ${path}/pkg/serializer.AgentPayloadVersion=${payloadVersion}"
          "-X ${path}/pkg/collector/python.pythonHome3=${pythonWithIntegrations}"
          "-X ${path}/pkg/config.DefaultPython=3"
          "-r ${pythonWithIntegrations}/lib"
        ];

        preBuild = ''
          # Keep directories to generate in sync with tasks/go.py
          go generate ./pkg/status ./cmd/agent/gui
        '';

        # DataDog use paths relative to the agent binary, so fix these.
        postPatch = ''
          sed -e "s|PyChecksPath =.*|PyChecksPath = \"$out/${pythonWithIntegrations.sitePackages}\"|" \
              -e "s|distPath =.*|distPath = \"$out/share/datadog-agent\"|" \
              -i cmd/agent/common/common_nix.go
          sed -e "s|/bin/hostname|${lib.getBin hostname}/bin/hostname|" \
              -i pkg/util/hostname_nix.go
        '';

        # Install the config files and python modules from the "dist" dir into standard paths.
        postInstall = ''
          mkdir -p $out/${pythonWithIntegrations.sitePackages} $out/share/datadog-agent
          cp -R $src/cmd/agent/dist/{checks,utils,config.py} $out/${pythonWithIntegrations.sitePackages}
          cp -R $src/pkg/status/templates $out/share/datadog-agent
        '';

        meta = with lib; {
          description = ''
            Event collector for the DataDog analysis service
            -- v6 new golang implementation.
          '';
          homepage = "https://www.datadoghq.com";
          license = licenses.bsd3;
          maintainers = with maintainers; [ thoughtpolice domenkozar rvl viraptor ];
        };
      };
    in
    symlinkJoin {
      name = "datadog";
      paths = thisPackages ++ thisIntegrations ++ [ rtloader ];

      passthru = {
        packages = allPackages;
        integrations = allIntegrations;
        python = pythonWithIntegrations;

        inherit buildEnv;
        withTags = tags: buildEnv { inherit tags; };
        withIntegrations = integrations: buildEnv { inherit integrations; };
      };

      meta = with lib; {
        description = ''
          A standard, lightweight Datadog environment with datadog-agent, process-agent, trace-agent and the core
          system metrics integrations installed.
        '';
        homepage = "https://www.datadoghq.com";
        license = licenses.bsd3;
        maintainers = with maintainers; [ thoughtpolice domenkozar rvl viraptor ];
      };
    };

  buildEnv = mkBuildEnv { } [ ] [ ];
in

buildEnv {
  # The set of packages to include in the default Datadog environment. This should be kept somewhat minimal.
  packages = ({ all, ... }: with all; [
    agent
    process-agent
    trace-agent
  ]);

  # The set of integrations to include in the default Datadog environment. This should be kept somewhat minimal.
  integrations = ({ all, ... }: with all; [
    disk
    network
    process
  ]);
}
