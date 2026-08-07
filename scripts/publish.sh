#!/usr/bin/env bash
#
# Walks through publishing be.imgn.parent:parent to Maven Central.
#
# Safe to re-run: every step detects what is already done and skips it. Nothing
# becomes public until you press Publish in the Central portal, which this
# script cannot and does not do for you.
#
# Usage:  scripts/publish.sh [releaseVersion] [nextVersion]
#         scripts/publish.sh 2026-08 2026-09

# This script is bash, not zsh: it relies on BASH_SOURCE, read -p and <<< .
# Re-exec under bash however it was invoked, so `zsh publish.sh` also works.
if [ -z "${BASH_VERSION:-}" ]; then
    command -v bash >/dev/null 2>&1 || {
        echo 'error bash is required but not installed.' >&2
        exit 1
    }
    exec bash "$0" "$@"
fi

set -euo pipefail

REPO='imgn-dev/imgn-parent'
DOMAIN='imgn.be'
NAMESPACE='be.imgn'
KEYSERVER='keyserver.ubuntu.com'
PORTAL='https://central.sonatype.com/publishing/deployments'
VERSION_PATTERN='^[0-9]{4}-(0[1-9]|1[0-2])(-(0[1-9]|[12][0-9]|3[01]))?$'

# --- output helpers -----------------------------------------------------------

bold() { printf '\n\033[1m%s\033[0m\n' "$*"; }
info() { printf '  %s\n' "$*"; }
ok()   { printf '  \033[32mok\033[0m   %s\n' "$*"; }
warn() { printf '  \033[33mnote\033[0m %s\n' "$*"; }
die()  { printf '\n\033[31merror\033[0m %s\n' "$*" >&2; exit 1; }

# Asks a yes/no question. Anything but an explicit y aborts.
confirm() {
    local answer
    read -r -p "  $1 [y/N] " answer
    [[ $answer == [yY] ]] || die 'Stopped at your request.'
}

# --- pure helpers, unit-testable ----------------------------------------------

valid_version() {
    [[ $1 =~ $VERSION_PATTERN ]]
}

# Later of two date-ish versions must be strictly greater, lexically.
version_is_after() {
    [[ $1 > $2 ]]
}

# --- steps --------------------------------------------------------------------

check_tools() {
    bold '1. Preflight'
    local tool
    for tool in gpg gh git dig; do
        command -v "$tool" >/dev/null || die "$tool is not installed."
    done
    ok 'gpg, gh, git, dig present'

    gh auth status >/dev/null 2>&1 || die 'gh is not authenticated. Run: gh auth login'
    ok "gh authenticated as $(gh api user --jq .login)"

    gh repo view "$REPO" >/dev/null 2>&1 || die "Cannot see $REPO."
    ok "$REPO reachable"

    [[ -z $(git status --porcelain) ]] \
        || die 'Working tree is dirty. Commit or stash first.'
    ok 'working tree clean'

    local branch
    branch=$(git rev-parse --abbrev-ref HEAD)
    [[ $branch == main ]] || die "On branch '$branch'. Release runs from main."
    ok 'on main'

    git fetch --quiet origin main
    [[ -z $(git log origin/main..HEAD --oneline) ]] \
        || die 'You have unpushed commits. Push them first.'
    ok 'in sync with origin/main'
}

check_namespace() {
    bold "2. Namespace $NAMESPACE"
    if dig TXT "$DOMAIN" +short | grep -qv 'v=spf1'; then
        ok "TXT records present on $DOMAIN"
    else
        warn "No non-SPF TXT record on $DOMAIN."
    fi
    info "This script cannot read the Central portal."
    confirm "Does the portal show $NAMESPACE as VERIFIED?"
}

setup_key() {
    bold '3. Signing key'
    local keys
    keys=$(gpg --list-secret-keys --keyid-format=long --with-colons 2>/dev/null \
           | awk -F: '/^sec/ {print $5}')

    if [[ -z $keys ]]; then
        info 'No secret key found. Creating one — choose RSA 4096.'
        confirm 'Generate a GPG key now?'
        gpg --full-generate-key
        keys=$(gpg --list-secret-keys --keyid-format=long --with-colons \
               | awk -F: '/^sec/ {print $5}')
        [[ -n $keys ]] || die 'Still no secret key after generation.'
    fi

    if [[ $(wc -l <<<"$keys") -gt 1 ]]; then
        info 'Several secret keys found:'
        gpg --list-secret-keys --keyid-format=long
        read -r -p '  Key ID to sign with: ' KEY_ID
    else
        KEY_ID=$keys
    fi
    [[ -n ${KEY_ID:-} ]] || die 'No key ID selected.'
    ok "using key $KEY_ID"

    info "Publishing the public half to $KEYSERVER."
    info 'Central rejects any bundle whose public key it cannot find.'
    gpg --keyserver "$KEYSERVER" --send-keys "$KEY_ID" \
        || warn 'Send failed. Retry manually before releasing.'
}

set_secrets() {
    bold '4. Repository secrets'
    local existing
    existing=$(gh secret list --repo "$REPO" --json name --jq '.[].name' 2>/dev/null || true)

    set_secret() {
        local name=$1 prompt=$2 value
        if grep -qx "$name" <<<"$existing"; then
            info "$name already set — skipping. Delete it in GitHub to replace."
            return
        fi
        # -s: never echoed, never in shell history, never written to disk.
        read -r -s -p "  $prompt: " value
        printf '\n'
        [[ -n $value ]] || die "$name cannot be empty."
        printf '%s' "$value" | gh secret set "$name" --repo "$REPO"
        unset value
        ok "$name set"
    }

    set_secret CENTRAL_TOKEN_USERNAME 'Central token username'
    set_secret CENTRAL_TOKEN_PASSWORD 'Central token password'
    set_secret GPG_PASSPHRASE         "Passphrase for key $KEY_ID"

    if grep -qx GPG_PRIVATE_KEY <<<"$existing"; then
        info 'GPG_PRIVATE_KEY already set — skipping.'
    else
        info 'Exporting the private key straight into the secret (no file on disk).'
        gpg --armor --export-secret-keys "$KEY_ID" \
            | gh secret set GPG_PRIVATE_KEY --repo "$REPO"
        ok 'GPG_PRIVATE_KEY set'
    fi
}

run_release() {
    bold '5. Release'
    info "Release version : $RELEASE_VERSION"
    info "Next version    : $NEXT_VERSION-SNAPSHOT"
    info 'This publishes signed artifacts to Central, tags the commit and pushes.'
    info 'Nothing becomes public until you press Publish in the portal.'
    confirm 'Start the release workflow?'

    gh workflow run release.yml --repo "$REPO" \
        -f "releaseVersion=$RELEASE_VERSION" \
        -f "nextVersion=$NEXT_VERSION"

    info 'Waiting for the run to appear.'
    local id='' attempt
    for attempt in 1 2 3 4 5 6 7 8 9 10; do
        sleep 3
        id=$(gh run list --repo "$REPO" --workflow release.yml \
             --limit 1 --json databaseId --jq '.[0].databaseId' 2>/dev/null || true)
        [[ -n $id && $id != null ]] && break
    done
    [[ -n $id && $id != null ]] || die 'Run did not appear. Check the Actions tab.'

    ok "watching run $id"
    if gh run watch "$id" --repo "$REPO" --exit-status --interval 15; then
        bold 'Published to the staging area'
        info "Open $PORTAL and press Publish."
        info 'Inspect the uploaded files first — that button is the point of no return.'
    else
        die "Run $id failed. Inspect it with: gh run view $id --repo $REPO --log-failed"
    fi
}

# --- entry point --------------------------------------------------------------

main() {
    RELEASE_VERSION=${1:-}
    NEXT_VERSION=${2:-}

    [[ -n $RELEASE_VERSION && -n $NEXT_VERSION ]] \
        || die "Usage: $0 <releaseVersion> <nextVersion>   e.g. $0 2026-08 2026-09"

    valid_version "$RELEASE_VERSION" \
        || die "releaseVersion '$RELEASE_VERSION' must be YYYY-MM or YYYY-MM-DD."
    valid_version "$NEXT_VERSION" \
        || die "nextVersion '$NEXT_VERSION' must be YYYY-MM or YYYY-MM-DD."
    version_is_after "$NEXT_VERSION" "$RELEASE_VERSION" \
        || die "nextVersion must be later than releaseVersion."

    check_tools
    check_namespace
    setup_key
    set_secrets
    run_release
}

# Only run when executed, so the helpers above can be sourced and tested.
if [[ ${BASH_SOURCE[0]} == "${0}" ]]; then
    main "$@"
fi
