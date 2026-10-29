# Antigravity agent and model quotas.
#
# Reads the access token that agy stores in the gemini/antigravity keyring entry,
# then asks daily-cloudcode-pa.googleapis.com for the companion project and its
# quota summary. agy owns the login: this module never refreshes the token.

antigravity_request() {
    aiq_request "$headers" "https://daily-cloudcode-pa.googleapis.com/v1internal:$1" \
        -H "Content-Type: application/json" \
        -H "User-Agent: dms-ai-quotas" \
        --data "$2"
}

fetch_antigravity() {
    if ! command -v agy >/dev/null 2>&1; then
        aiq_status unavailable missing_dependency "Antigravity requires agy CLI."
        return
    fi

    agy_out=$(agy -p '/usage' --output-format json 2>/dev/null || true)
    if [ -z "$agy_out" ]; then
        aiq_status unavailable not_authenticated "Antigravity is not logged in. Start agy and sign in."
        return
    fi

    printf '%s' "$agy_out" | jq -c 'select(.command.name == "usage") | .command.data' | {
        read -r data
        if [ -z "$data" ] || [ "$data" = "null" ]; then
            aiq_status error "" "Failed to load Antigravity usage"
            return
        fi

        printf '%s' "$data" | jq -c '{
            status: "ok",
            plan: "Google AI Premium",
            entries: [.groups[] | .name as $group | .buckets[] | {
                name: ((if $group != null and $group != "" then $group + " - " else "" end) + (.name // .displayName // .id)),
                percentUsed: ((1 - (.remaining_fraction // 1.0)) * 100 | round),
                resetAt: (.reset_time | strptime("%Y-%m-%dT%H:%M:%SZ") | mktime)
            }]
        }'
    }
}
