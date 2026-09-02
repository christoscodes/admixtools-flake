# package.nix
{
  lib,
  stdenv,
  fetchFromGitHub,
  gfortran,
  gsl,
  openblas,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "admixtools";
  version = "8.0.2";

  src = fetchFromGitHub {
    owner = "DReichLab";
    repo = "AdmixTools";
    tag = "v${finalAttrs.version}";
    hash = "sha256-vcYXUiSsGyhshSp1am/wB1b9gU3zuRVpdboUFuhENiw=";
  };

  # gfortran is only needed so libgfortran is available for the BLAS/LAPACK
  # link; the C sources are compiled with `cc` from stdenv. gsl + openblas
  # cover everything else — openblas bundles LAPACK and LAPACKE.
  nativeBuildInputs = [ gfortran ];
  buildInputs = [ gsl openblas ];

  dontConfigure = true; # upstream has no ./configure, just a Makefile in src/

  # The Makefile lives in src/ and hardcodes CC=cc plus some Harvard-cluster
  # -I/-L paths. `cc` resolves to the stdenv compiler; the bogus paths are
  # harmless (they don't exist), and Nix's cc-wrapper injects the correct
  # include/lib paths for gsl and openblas from buildInputs.
  buildPhase = ''
    runHook preBuild
    make -C src CC=cc
    runHook postBuild
  '';

  # Upstream `make install` copies to a repo-local ./bin; we install the known
  # program set directly so the output is predictable. This list is the
  # PROGS/PROGS3/PROGS4 variables from src/Makefile — update it if a version
  # bump adds tools. The guard skips anything a given release doesn't build,
  # and we fail loudly if the core binary is missing.
  installPhase = ''
    runHook preInstall
    mkdir -p "$out/bin"
    for prog in \
      qp3Pop qpDstat qpF4ratio qpAdm qpWave qp4diff dowtjack qpBound \
      qpGraph qpreroot qpff3base qpDpart qpfstats qpfmv qpmix \
      convertf mergeit snpunion simpjack2 grabpars easystats easycheck \
      easylite multimerge geno_single transpose merge_transpose nickhash; do
      if [ -x "src/$prog" ]; then
        install -Dm755 "src/$prog" "$out/bin/$prog"
      fi
    done
    [ -x "$out/bin/qpAdm" ] || { echo "qpAdm was not built" >&2; exit 1; }
    runHook postInstall
  '';

  meta = {
    description = "Tools for inferring population history from genetic data (qpAdm, qpGraph, qpDstat, f-statistics)";
    homepage = "https://github.com/DReichLab/AdmixTools";
    # ADMIXTOOLS ships a custom, non-OSI license. Marked unfree so it won't be
    # pushed to public binary caches. Read the repo's LICENSE and adjust if
    # your reading permits something more specific.
    license = lib.licenses.unfree;
    platforms = lib.platforms.unix;
    mainProgram = "qpAdm";
  };
})
