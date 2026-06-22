#!/usr/bin/env bash
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Org-mode agenda parser → JSON
# Scans every .org file in ~/Notes and emits a JSON array of entries.
# Each entry: title, state, priority, tags[], deadline, deadline_time,
#             scheduled, scheduled_time, closed, closed_time, body, file
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
set -euo pipefail

NOTES_DIR="$HOME/Notes"

# Collect all entries as newline-delimited JSON objects
entries=""

for orgfile in "$NOTES_DIR"/*.org; do
    [[ -f "$orgfile" ]] || continue
    filename="$(basename "$orgfile" .org)"

    # State machine variables
    in_heading=false
    title=""
    state=""
    priority=""
    tags=""
    depth=0
    deadline=""
    deadline_time=""
    scheduled=""
    scheduled_time=""
    closed=""
    closed_time=""
    body=""
    body_lines=0

    flush_entry() {
        if [[ -n "$title" ]]; then
            # Build tags JSON array
            tags_json="[]"
            if [[ -n "$tags" ]]; then
                tags_json=$(echo "$tags" | tr ':' '\n' | grep -v '^$' | jq -R . | jq -s .)
            fi

            entry=$(jq -n \
                --arg title "$title" \
                --arg state "$state" \
                --arg priority "$priority" \
                --argjson tags "$tags_json" \
                --arg depth "$depth" \
                --arg deadline "$deadline" \
                --arg deadline_time "$deadline_time" \
                --arg scheduled "$scheduled" \
                --arg scheduled_time "$scheduled_time" \
                --arg closed "$closed" \
                --arg closed_time "$closed_time" \
                --arg body "$body" \
                --arg file "$filename" \
                '{
                    title: $title,
                    state: $state,
                    priority: $priority,
                    tags: $tags,
                    depth: ($depth | tonumber),
                    deadline: $deadline,
                    deadline_time: $deadline_time,
                    scheduled: $scheduled,
                    scheduled_time: $scheduled_time,
                    closed: $closed,
                    closed_time: $closed_time,
                    body: $body,
                    file: $file
                }')
            entries="${entries}${entry}"$'\n'
        fi
    }

    while IFS= read -r line || [[ -n "$line" ]]; do
        # Check for heading
        if [[ "$line" =~ ^(\*+)[[:space:]]+(.*) ]]; then
            # Flush previous entry
            flush_entry

            # Reset
            depth=${#BASH_REMATCH[1]}
            rest="${BASH_REMATCH[2]}"
            state=""
            priority=""
            tags=""
            deadline=""
            deadline_time=""
            scheduled=""
            scheduled_time=""
            closed=""
            closed_time=""
            body=""
            body_lines=0

            # Extract state (TODO/DONE/etc)
            if [[ "$rest" =~ ^(TODO|DONE|WAITING|CANCELLED|NEXT|HOLD)[[:space:]]+(.*) ]]; then
                state="${BASH_REMATCH[1]}"
                rest="${BASH_REMATCH[2]}"
            fi

            # Extract priority
            if [[ "$rest" =~ ^\[#([A-C])\][[:space:]]+(.*) ]]; then
                priority="${BASH_REMATCH[1]}"
                rest="${BASH_REMATCH[2]}"
            fi

            # Extract tags at end
            if [[ "$rest" =~ ^(.*)[[:space:]]+(:[a-zA-Z0-9_:]+:)[[:space:]]*$ ]]; then
                title="${BASH_REMATCH[1]}"
                tags="${BASH_REMATCH[2]}"
            else
                title="$rest"
            fi
            title="${title%"${title##*[![:space:]]}"}" # rtrim

            in_heading=true
            continue
        fi

        # Body lines (after a heading)
        if $in_heading; then
            # Extract DEADLINE
            if [[ "$line" =~ DEADLINE:[[:space:]]*[\<\[]([0-9]{4}-[0-9]{2}-[0-9]{2})[[:space:]]+[A-Za-z]+ ]]; then
                deadline="${BASH_REMATCH[1]}"
                if [[ "$line" =~ DEADLINE:[[:space:]]*[\<\[][0-9]{4}-[0-9]{2}-[0-9]{2}[[:space:]]+[A-Za-z]+[[:space:]]+([0-9]{2}:[0-9]{2}) ]]; then
                    deadline_time="${BASH_REMATCH[1]}"
                fi
            elif [[ "$line" =~ DEADLINE:[[:space:]]*[\<\[]([0-9]{4}-[0-9]{2}-[0-9]{2}) ]]; then
                deadline="${BASH_REMATCH[1]}"
            fi

            # Extract SCHEDULED
            if [[ "$line" =~ SCHEDULED:[[:space:]]*[\<\[]([0-9]{4}-[0-9]{2}-[0-9]{2})[[:space:]]+[A-Za-z]+ ]]; then
                scheduled="${BASH_REMATCH[1]}"
                if [[ "$line" =~ SCHEDULED:[[:space:]]*[\<\[][0-9]{4}-[0-9]{2}-[0-9]{2}[[:space:]]+[A-Za-z]+[[:space:]]+([0-9]{2}:[0-9]{2}) ]]; then
                    scheduled_time="${BASH_REMATCH[1]}"
                fi
            elif [[ "$line" =~ SCHEDULED:[[:space:]]*[\<\[]([0-9]{4}-[0-9]{2}-[0-9]{2}) ]]; then
                scheduled="${BASH_REMATCH[1]}"
            fi

            # Extract CLOSED
            if [[ "$line" =~ CLOSED:[[:space:]]*[\<\[]([0-9]{4}-[0-9]{2}-[0-9]{2})[[:space:]]+[A-Za-z]+ ]]; then
                closed="${BASH_REMATCH[1]}"
                if [[ "$line" =~ CLOSED:[[:space:]]*[\<\[][0-9]{4}-[0-9]{2}-[0-9]{2}[[:space:]]+[A-Za-z]+[[:space:]]+([0-9]{2}:[0-9]{2}) ]]; then
                    closed_time="${BASH_REMATCH[1]}"
                fi
            elif [[ "$line" =~ CLOSED:[[:space:]]*[\<\[]([0-9]{4}-[0-9]{2}-[0-9]{2}) ]]; then
                closed="${BASH_REMATCH[1]}"
            fi

            # Collect body text (skip empty, property drawers, timestamp-only lines)
            stripped="${line#"${line%%[![:space:]]*}"}" # ltrim
            if [[ -n "$stripped" && ! "$stripped" =~ ^: && ! "$stripped" =~ ^(DEADLINE|SCHEDULED|CLOSED): && $body_lines -lt 3 ]]; then
                # Skip lines that are only timestamps
                if [[ ! "$stripped" =~ ^\[?[0-9]{4}-[0-9]{2}-[0-9]{2} || ${#stripped} -gt 25 ]]; then
                    if [[ -n "$body" ]]; then
                        body="$body\n$stripped"
                    else
                        body="$stripped"
                    fi
                    body_lines=$((body_lines + 1))
                fi
            fi
        fi
    done < "$orgfile"

    # Flush last entry in file
    flush_entry
done

# Combine all entries into a sorted JSON array
# Sort: active items first (TODO=0, NEXT=0, WAITING=1, none=2, HOLD=3, DONE=4, CANCELLED=5), then by effective date
if [[ -n "$entries" ]]; then
    echo "$entries" | grep -v '^$' | jq -s '
        def state_order:
            if . == "TODO" then 0
            elif . == "NEXT" then 0
            elif . == "WAITING" then 1
            elif . == "" then 2
            elif . == "HOLD" then 3
            elif . == "DONE" then 4
            elif . == "CANCELLED" then 5
            else 2 end;

        def effective_date:
            if .deadline != "" then .deadline
            elif .scheduled != "" then .scheduled
            else "9999-12-31" end;

        sort_by([(.state | state_order), effective_date])
    '
else
    echo "[]"
fi
