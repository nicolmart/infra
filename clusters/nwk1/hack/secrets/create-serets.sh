#!/usr/bin/env bash

# Wire up the env and validations
__dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${__dir}/environment.sh"


# Create secrets file
truncate -s 0 "${GENERATED_SECRETS}"

#
# Helm Secrets
#

# Generate Helm Secrets
txt=$(find "${CLUSTER_ROOT}" -type f -name "*.txt")

if [[ ( -n $txt ) ]];
then
    # shellcheck disable=SC2129
    printf "%s\n%s\n%s\n" "#" "# Auto-generated helm secrets -- DO NOT EDIT." "#" >> "${GENERATED_SECRETS}"

    for file in "${CLUSTER_ROOT}"/**/*.txt; do
        # Get the path and basename of the txt file
        # e.g. "deployments/default/pihole/pihole"
        secret_path="$(dirname "$file")/$(basename -s .txt "$file")"
        # Get the filename without extension
        # e.g. "pihole"
        secret_name=$(basename "${secret_path}")
        # Get the relative path of deployment
        deployment=${file#"${CLUSTER_ROOT}"}
        # Get the namespace (based on folder path of manifest)
        namespace=$(echo "${deployment}" | awk -F/ '{print $2}')
        echo "[*] Generating helm secret '${secret_name}' in namespace '${namespace}'..."
        # Create secret
        envsubst <"$file" |
            kubectl -n "${namespace}" create secret generic "${secret_name}-helm-values" \
                --from-file=/dev/stdin --dry-run=client -o json |
            kubeseal --format=yaml --cert="${PUB_CERT}" \
                >>"${GENERATED_SECRETS}"
        echo "---" >>"${GENERATED_SECRETS}"
    done

    # Replace stdin with values.yaml
    sed -i 's/stdin\:/values.yaml\:/g' "${GENERATED_SECRETS}"
fi

#
# Generic Secrets
#

# shellcheck disable=SC2129
printf "%s\n%s\n%s\n" "#" "# Auto-generated generic secrets -- DO NOT EDIT." "#" >> "${GENERATED_SECRETS}"

# Cloudflare API Key
kubectl create secret generic cloudflare-api-key \
    --from-literal=api-key="${CF_API_KEY}" \
    --namespace cert-manager --dry-run=client -o json |
    kubeseal --format=yaml --cert="${PUB_CERT}" |
    # Remove null keys
    yq eval 'del(.metadata.creationTimestamp)' - |
    yq eval 'del(.spec.template.metadata.creationTimestamp)' - |
    # Format yaml file
    sed -e '1s/^/---\n/' |
    # Write secret
    tee -a "${GENERATED_SECRETS}" >/dev/null 2>&1

# Cloudflare Origin CA
kubectl create secret generic cloudflare-origin-ca \
    --from-literal=key="${CF_ORIGIN_CA}" \
    --namespace cert-manager --dry-run=client -o json |
    kubeseal --format=yaml --cert="${PUB_CERT}" |
    # Remove null keys
    yq eval 'del(.metadata.creationTimestamp)' - |
    yq eval 'del(.spec.template.metadata.creationTimestamp)' - |
    # Format yaml file
    sed -e '1s/^/---\n/' |
    # Write secret
    tee -a "${GENERATED_SECRETS}" >/dev/null 2>&1

# Flux discord webhook
kubectl create secret generic discord-webhook \
    --from-literal=address="${FLUX_DISCORD_WEBHOOK}" \
    --namespace flux-system --dry-run=client -o json |
    kubeseal --format=yaml --cert="${PUB_CERT}" |
    # Remove null keys
    yq eval 'del(.metadata.creationTimestamp)' - |
    yq eval 'del(.spec.template.metadata.creationTimestamp)' - |
    # Format yaml file
    sed -e '1s/^/---\n/' |
    # Write secret
    tee -a "${GENERATED_SECRETS}" >/dev/null 2>&1

# Flux Webhook Token
kubectl create secret generic github-webhook-token \
    --from-literal=token="${FLUX_GITHUB_WEBHOOK}" \
    --namespace flux-system --dry-run=client -o json |
    kubeseal --format=yaml --cert="${PUB_CERT}" |
    # Remove null keys
    yq eval 'del(.metadata.creationTimestamp)' - |
    yq eval 'del(.spec.template.metadata.creationTimestamp)' - |
    # Format yaml file
    sed -e '1s/^/---\n/' |
    # Write secret
    tee -a "${GENERATED_SECRETS}" >/dev/null 2>&1

# Flux API token
kubectl create secret generic github-api-token \
    --from-literal=token="${FLUX_GITHUB_API}" \
    --namespace flux-system --dry-run=client -o json |
    kubeseal --format=yaml --cert="${PUB_CERT}" |
    # Remove null keys
    yq eval 'del(.metadata.creationTimestamp)' - |
    yq eval 'del(.spec.template.metadata.creationTimestamp)' - |
    # Format yaml file
    sed -e '1s/^/---\n/' |
    # Write secret
    tee -a "${GENERATED_SECRETS}" >/dev/null 2>&1



# Remove empty new-lines
sed -i '/^[[:space:]]*$/d' "${GENERATED_SECRETS}"

# Validate Yaml
if ! yq eval "${GENERATED_SECRETS}" >/dev/null 2>&1; then
    echo "Errors in YAML"
    exit 1
fi

exit 0
