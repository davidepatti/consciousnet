# Consciousnet

Consciousnet is an old Perl chatbot experiment built around a modified
`Chatbot::Eliza` script and internet snippets.

Reference paper: V. Catania, S. Monteleone, M. Palesi, and D. Patti, "Impact of
Users' Beliefs in Text-Based Linguistic Interaction," IEEE Access, vol. 8,
pp. 46861-46867, 2020, doi:
[10.1109/ACCESS.2020.2978977](https://doi.org/10.1109/ACCESS.2020.2978977)
([IEEE Xplore](https://ieeexplore.ieee.org/abstract/document/9026943)).

## Current status

The old Google Programmable Search / Custom Search setup is deprecated and is no
longer part of the current branch. The exact pre-modernization version is
preserved as the Git tag `legacy-2026-04-29`.

The current branch is intentionally simple: it sends a string to Brave Search
API and uses returned web snippets as NET responses.

## Install on macOS or Ubuntu Linux

Clone the project:

```sh
git clone https://github.com/davidepatti/consciousnet
cd consciousnet
```

Run setup:

```sh
./setup.sh
```

The setup script:

- checks Perl and required HTTP/JSON/SSL modules
- installs missing HTTP/SSL modules on Ubuntu with `apt-get`, or locally under
  `local/` with CPAN on macOS and other systems
- copies the repository's modified `Eliza.pm` into `local/Chatbot/Eliza.pm`
  instead of replacing a system Perl module
- creates `consciousnet.conf` from `consciousnet.conf.example`
- creates `logs/` for session logs
- runs a Perl syntax check

`consciousnet.conf` is ignored by Git and should not be committed.

## Configure Brave Search

Use the Brave Search API key you already have. Put it in `consciousnet.conf`:

```ini
brave_api_key=YOUR_BRAVE_SEARCH_API_KEY
brave_endpoint=https://api.search.brave.com/res/v1/web/search
brave_country=us
brave_search_lang=en
brave_ui_lang=en-US
brave_safesearch=off
brave_spellcheck=1
meta_file=annette.meta
max_answer_words=25
page_size=5
http_timeout=10
```

`meta_file` points to the Eliza meta script. Relative paths are resolved from
the project directory. To use the Italian conversation script, set it to
`gioio-ita.meta` in your private `consciousnet.conf`.

`max_answer_words` rejects overlong candidate web-search answers before one is
selected. Answers are not truncated.
Search snippets are first reduced to one complete sentence.

An Italian example config is available at `consciousnet-it.conf.example`; it
uses `gioio-ita.meta` and Italian Brave Search settings.

Or keep the key out of the file:

```sh
export BRAVE_SEARCH_API_KEY=YOUR_BRAVE_SEARCH_API_KEY
```

Useful Brave docs:

- [Brave Search API](https://brave.com/search/api/)
- [Brave API authentication](https://api-dashboard.search.brave.com/documentation/guides/authentication)

## Run

Start Consciousnet:

```sh
./docgioio
```

For faster local testing:

```sh
./docgioio --quick
```

Debug logging is opt-in:

```sh
./docgioio --quick --debug
```

Then type a query-like prompt, for example:

```text
who is davide
```

You should see:

```text
DEBUG: Brave Search query: ...
```

For an offline smoke test without network calls:

```sh
./docgioio --quick --no-net
```

If Perl reports `Can't verify SSL peers without knowing which Certificate
Authorities to trust`, rerun `./setup.sh`. The setup script installs
`Mozilla::CA`, and `entity.pl` uses it automatically for HTTPS verification.

To use a different credential file:

```sh
./docgioio --config=/path/to/consciousnet.conf
```

or:

```sh
CONSCIOUSNET_CONFIG=/path/to/consciousnet.conf ./docgioio
```

## Old Google Version

The previous README and Google-based installation flow are explicitly
deprecated, but remain available for old users and old virtual machines at:

[legacy-2026-04-29 README](https://github.com/davidepatti/consciousnet/tree/legacy-2026-04-29)

To check out the old version:

```sh
git clone https://github.com/davidepatti/consciousnet
cd consciousnet
git checkout legacy-2026-04-29
```

Then follow the README from that tagged version. That old flow expects
`Data.pm`, old Google Custom Search credentials, CPAN `Chatbot::Eliza`, and
manual replacement of the installed `Eliza.pm`. It is preserved only so existing
users can reproduce the historical behavior.
