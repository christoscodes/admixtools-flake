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

  # 8.0.2 still has a K&R forward decl `void setgtime ();` in qpgsubs.c while
  # qpsubs.h prototypes `void setgtime(double *)`. GCC 15+ defaults to C23,
  # where () means (void), so the types conflict. Same one-liner as upstream
  # master / BioArchLinux.
  postPatch = ''
    substituteInPlace src/qpgsubs.c \
      --replace-fail 'void setgtime ();' 'void setgtime (double *time);'
  '';

  # gfortran is only needed so libgfortran is available for the BLAS/LAPACK
  # link; the C sources are compiled with `cc` from stdenv. gsl + openblas
  # cover everything else — openblas bundles LAPACK and LAPACKE.
  nativeBuildInputs = [ gfortran ];
  buildInputs = [ gsl openblas ];

  # Upstream has no ./configure. The Makefile lives in src/ and hardcodes
  # CC=cc plus some Harvard-cluster -I/-L paths. Those paths do not exist
  # here; the cc-wrapper injects gsl/openblas from buildInputs.
  dontConfigure = true;
  enableParallelBuilding = true;

  # Keep empty () prototypes with pre-C23 meaning if any others remain.
  env.NIX_CFLAGS_COMPILE = "-std=gnu17";

  makeFlags = [
    "-C"
    "src"
    "CC=${stdenv.cc.targetPrefix}cc"
  ];

  # Upstream `make install` copies into a repo-local ../bin. Install the
  # known program set (PROGS + PROGS3 + PROGS4 from the Makefile) ourselves.
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
