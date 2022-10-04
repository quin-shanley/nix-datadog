final: prev:

{
  datadog = final.callPackage ./datadog.nix {
    python = final.python3;
  };
}
