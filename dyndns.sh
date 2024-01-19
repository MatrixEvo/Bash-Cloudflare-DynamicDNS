#!/usr/bin/env bash

# Super Simple Cloudflare Dynamic DNS written in Bash
# By MatrixEvo
# Created on 18th January 2024
# Last Updated on 18th January 2024

# Example Usage - CronJob - Check every minute
# * * * * * dyndns.sh >dyndns.log 2>&1

# Cloudflare Authentication - API Token with (Zone : DNS : Read) and (Zone : DNS : Edit) permission
cloudflare_email="email@example.com" # Change This
cloudflare_api_token="" # Change This

# Zone Identifier from Cloudflare Dashboard - Domain
zone_identifier="" # Change This

# DNS Record Info - DNS Record Identifier is retrieved automatically
record_name="subdomain.example.com" # Change This
proxy_state="false" # Change This based on your needs
record_type="A" # Change This based on your needs
record_ttl="60" # Change This based on your needs

# ===== Nothing to change below =====

check_variable() {
  local count
  count=0
  for var in "${@}"; do
    if [[ -z "${!var}" ]]; then
      echo "ERROR - variable \"${var}\" is empty"
      ((count++))
    fi
  done
  if [[ ${count} -ne 0 ]]; then
    exit 1
  fi
  unset count
}

check_valid_ipv4() {
    grep -oE "(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])"
}

# Documentation - https://developers.cloudflare.com/api/operations/dns-records-for-a-zone-list-dns-records
get_dns_record_identifier() {
  curl -4sS --request GET \
    --url "https://api.cloudflare.com/client/v4/zones/${zone_identifier}/dns_records" \
    --header 'Content-Type: application/json' \
    --header "X-Auth-Email: ${cloudflare_email}" \
    --header "Authorization: Bearer ${cloudflare_api_token}" \
    | jq -r --arg record_name "${record_name}" '.result[] | select(.name == $record_name) | .id'
}

# Documentation - https://developers.cloudflare.com/api/operations/dns-records-for-a-zone-dns-record-details
get_record() {
  curl -4sS --request GET \
    --url "https://api.cloudflare.com/client/v4/zones/${zone_identifier}/dns_records/${dns_record_identifier}" \
    --header 'Content-Type: application/json' \
    --header "X-Auth-Email: ${cloudflare_email}" \
    --header "Authorization: Bearer ${cloudflare_api_token}" \
    | jq -r .result.content
}

# Documentation - https://developers.cloudflare.com/api/operations/dns-records-for-a-zone-update-dns-record
update_record() {
  curl -4sS --request PUT \
    --url "https://api.cloudflare.com/client/v4/zones/${zone_identifier}/dns_records/${dns_record_identifier}" \
    --header 'Content-Type: application/json' \
    --header "X-Auth-Email: ${cloudflare_email}" \
    --header "Authorization: Bearer ${cloudflare_api_token}" \
    --data '{
    "content": "'"${current_ip}"'",
    "name": "'"${record_name}"'",
    "proxied": '"${proxy_state}"',
    "type": "'"${record_type}"'",
    "ttl": '"${record_ttl}"'
  }' \
  | jq
}

start() {
  echo "Run at $(date "+%-d-%b-%Y %H:%M")"

  # Auto filled variables - Do not change - Gets Public IP from multiple sources
  dns_record_identifier="$(get_dns_record_identifier)"
  current_ip="$(curl -4s checkip.amazonaws.com || curl -4s api.ipify.org || curl -4s ipv4.icanhazip.com || curl -4s ip.matrixevo.com)"
  current_ip="$(check_valid_ipv4 <<< "${current_ip}")"
  cloudflare_current_ip="$(get_record)"

  echo "Cloudflare IP     - ${cloudflare_current_ip}"
  echo "Current Public IP - ${current_ip}"

  check_variable cloudflare_email cloudflare_api_token zone_identifier record_name proxy_state record_type record_ttl dns_record_identifier current_ip cloudflare_current_ip

  if [[ ! "${cloudflare_current_ip}" == "${current_ip}" ]]; then
    echo "Not Match"
    echo
    update_record
    echo
  else
    echo "OK - No Action Required"
  fi
}

start
