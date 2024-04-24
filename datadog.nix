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
  version = "7.49.0";
  payloadVersion = "5.0.97"; # keep this in sync with github.com/DataDog/agent-payload dependency
  sha256 = "sha256-bG8wsSQvZcG4/Th6mWVdVX9vpeYBZx8FxwdYXpIdXnU=";
  vendorSha256 = "sha256-5cChRhi1aLoNPrMPgPwNuhwQOTkc/eOZOH1nZ69d2aQ=";

  ddtrace = callPackage ./ddtrace.nix { inherit python; };

  mkBuildEnv =
    prevAttrs:
    prevPackagesFns:
    prevIntegrationsFns:
    { packages ? { enabled ? [ ], all, ... }: enabled
    , integrations ? { enabled ? [ ], all, ... }: enabled
    , src ? fetchFromGitHub {
        inherit owner repo sha256;
        rev = version;
      }
    , ...
    }@attrs:
    let
      allIntegrations = lib.filterAttrs (_: lib.isDerivation) (callPackage ./integrations.nix {
        inherit ddtrace python;
      });
      allPackages = lib.filterAttrs (_: lib.isDerivation) (callPackage ./packages.nix {
        inherit mkDatadogPackage rtloader withSystemd;
        python = pythonWithIntegrations;
      });

      thisAttrs = prevAttrs // attrs;

      thisIntegrationsFns = prevIntegrationsFns ++ [ integrations ];
      thisIntegrations = builtins.foldl'
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

      pythonWithIntegrations = python.withPackages (_: thisIntegrations ++ [ allIntegrations.base ]);
      rtloader = callPackage ./rtloader.nix {
        inherit src version;
        python = pythonWithIntegrations;
      };

      mkDatadogPackage = fn:
        let
          defaults = rec {
            pname = "datadog";
            inherit src vendorSha256 version;

            doCheck = false;

            nativeBuildInputs = [ pkg-config ];
            buildInputs = [ rtloader ]
              ++ lib.optionals withSystemd [ systemd ];

            PKG_CONFIG_PATH = "${pythonWithIntegrations}/lib/pkgconfig";

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
              sed -e "s|PyChecksPath =.*|PyChecksPath = filepath.Join(_here, \"..\", \"${pythonWithIntegrations.sitePackages}\")|" \
                  -e "s|distPath =.*|distPath = filepath.Join(_here, \"..\", \"share/datadog-agent\")|" \
                  -i cmd/agent/common/common_nix.go
              sed -e "s|/bin/hostname|${lib.getBin hostname}/bin/hostname|" \
                  -i pkg/util/hostname_nix.go
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
        buildGoModule (defaults // (fn defaults));
    in
    symlinkJoin {
      name = "datadog";
      paths = thisPackages ++ thisIntegrations ++ [ rtloader ];
      buildInputs = [ makeWrapper ];
      postBuild = ''
        for i in $out/bin/*
        do
          cp --remove-destination "$(readlink "$i")" "$i"
          wrapProgram "$i" \
            --prefix LD_LIBRARY_PATH  : ${rtloader}/lib \
            --set PYTHONPATH "$out/${python.sitePackages}"'' + lib.optionalString withSystemd '' \
            --prefix LD_LIBRARY_PATH : ${lib.getLib systemd}/lib
        done

        # Install the config files and python modules from the "dist" dir into standard paths.
        mkdir -p $out/${pythonWithIntegrations.sitePackages} $out/share/datadog-agent $out/share/datadog-agent/conf.d
        cp -R ${src}/cmd/agent/dist/{checks,utils,config.py} $out/${pythonWithIntegrations.sitePackages}
        cp -R ${src}/pkg/status/templates $out/share/datadog-agent
      '';

      passthru = {
        packages = allPackages;
        integrations = allIntegrations;
        python = pythonWithIntegrations;

        inherit buildEnv;
        withPackages = packages: buildEnv { inherit packages; };
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

# The default distribution is a complete Datadog Agent build with all packages and integrations.
buildEnv {
  integrations = ({ all, ... }: builtins.attrValues all);
  packages = ({ all, ... }: builtins.attrValues all);
}
