{ fetchFromGitHub
, python
}:

python.pkgs.buildPythonPackage rec {
  name = "ddtrace";
  version = "2.8.2";
  format = "pyproject";
  src = fetchFromGitHub {
    owner = "DataDog";
    repo = "dd-trace-py";
    rev = "v${version}";
    sha256 = "sha256-3R381tC6gvBKkoyn+qR7vdCreK9V8Qvs4CLOhPOoFsE=";
  };
  propagatedBuildInputs = with python.pkgs; [
    attrs
    cython
    packaging
    protobuf
    setuptools
    six
    tenacity
  ];
  doCheck = true;
}
