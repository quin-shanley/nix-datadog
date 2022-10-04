{ stdenv
, cmake
, python
, src
, version
}:

stdenv.mkDerivation {
  pname = "datadog-agent-rtloader";
  src = "${src}/rtloader";
  inherit version;
  nativeBuildInputs = [ cmake ];
  buildInputs = [ python ];
  cmakeFlags = [ "-DBUILD_DEMO=OFF" "-DDISABLE_PYTHON2=ON" ];
}
