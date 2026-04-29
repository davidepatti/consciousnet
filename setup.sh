#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"
PROJECT_PERL5LIB=""

need_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

perl_modules_ok() {
  PERL5LIB="$PROJECT_PERL5LIB${PERL5LIB:+:$PERL5LIB}" \
    perl -MJSON::PP -MHTTP::Request -MLWP::UserAgent -MMozilla::CA -MURI::Escape -e 'print "ok\n"' >/dev/null 2>&1
}

perl_module_ok() {
  local module="$1"
  PERL5LIB="$PROJECT_PERL5LIB${PERL5LIB:+:$PERL5LIB}" \
    perl -M"$module" -e 'print "ok\n"' >/dev/null 2>&1
}

install_missing_cpan_modules() {
  local missing=()
  local module

  for module in LWP::UserAgent HTTP::Request Mozilla::CA URI::Escape; do
    if ! perl_module_ok "$module"; then
      missing+=("$module")
    fi
  done

  if [ "${#missing[@]}" -eq 0 ]; then
    return
  fi

  need_command cpan
  mkdir -p "$ROOT_DIR/local"

  for module in "${missing[@]}"; do
    echo "Installing missing Perl module locally: $module"
    PERL_MM_USE_DEFAULT=1 \
      PERL_MM_OPT="INSTALL_BASE=$ROOT_DIR/local" \
      PERL_MB_OPT="--install_base $ROOT_DIR/local" \
      PERL5LIB="$PROJECT_PERL5LIB${PERL5LIB:+:$PERL5LIB}" \
      cpan -T "$module"
  done
}

install_perl_modules() {
  if perl_modules_ok; then
    return
  fi

  echo "Installing missing Perl HTTP/JSON/SSL modules..."

  case "$(uname -s)" in
    Darwin)
      install_missing_cpan_modules
      ;;
    Linux)
      if command -v apt-get >/dev/null 2>&1; then
        sudo apt-get update
        sudo apt-get install -y perl libwww-perl libmozilla-ca-perl libio-socket-ssl-perl ca-certificates
      else
        install_missing_cpan_modules
      fi
      ;;
    *)
      install_missing_cpan_modules
      ;;
  esac
}

need_command perl
PERL_ARCHNAME="$(perl -MConfig -e 'print $Config{archname}')"
PROJECT_PERL5LIB="$ROOT_DIR/local/lib/perl5:$ROOT_DIR/local/lib/perl5/$PERL_ARCHNAME:$ROOT_DIR/local"
install_perl_modules

mkdir -p "$ROOT_DIR/local/Chatbot"
mkdir -p "$ROOT_DIR/logs"
cp "$ROOT_DIR/Eliza.pm" "$ROOT_DIR/local/Chatbot/Eliza.pm"

if [ ! -f "$ROOT_DIR/consciousnet.conf" ]; then
  cp "$ROOT_DIR/consciousnet.conf.example" "$ROOT_DIR/consciousnet.conf"
  chmod 600 "$ROOT_DIR/consciousnet.conf"
  echo "Created consciousnet.conf from consciousnet.conf.example."
else
  chmod 600 "$ROOT_DIR/consciousnet.conf"
  echo "Keeping existing consciousnet.conf."
fi

if [ -z "${BRAVE_SEARCH_API_KEY:-}" ] && ! grep -Eq '^[[:space:]]*brave_api_key[[:space:]]*=[[:space:]]*[^[:space:]#]+' "$ROOT_DIR/consciousnet.conf"; then
  echo "Add brave_api_key to consciousnet.conf, or set BRAVE_SEARCH_API_KEY."
fi

PERL5LIB="$PROJECT_PERL5LIB${PERL5LIB:+:$PERL5LIB}" perl -c "$ROOT_DIR/entity.pl"

cat <<'MSG'

Setup complete.

Next steps:
1. Set brave_api_key in consciousnet.conf, or set BRAVE_SEARCH_API_KEY.
2. Run: ./docgioio
3. For an offline smoke test, run: ./docgioio --quick --no-net

MSG
