#!/bin/bash

# Set your target domains (replace with your actual domains)
TARGET_DOMAINS=("example1.com" "example2.com" "example3.com")

# Set the path to the log file in the script's directory
LOG_FILE="$(dirname "$(realpath "$0")")/subdomains.log"

# Set the path to the domains directory
DOMAINS_DIR="$(dirname "$(realpath "$0")")/domains"

# Set the path to the Nuclei output directory
NUCLEI_OUTPUT_DIR="$(dirname "$(realpath "$0")")/nuclei_output"

# Set the path to the scanned subdomains directory
SCANNED_SUBDOMAINS_DIR="$(dirname "$(realpath "$0")")/scanned_subdomains"

# Set your Slack webhook URL
SLACK_WEBHOOK_URL="https://hooks.slack.com/services/url/"

# Set the maximum time for the curl command (in seconds)
MAX_CURL_TIME=60

# Global variable for domain_nuclei_dir
DOMAIN_NUCLEI_DIR=""

# Function to send Slack notification with improved error handling and logging
send_slack_notification() {
    local message="$1"

    # Use curl to send a message to Slack with a timeout
    local response
    response=$(curl --max-time "$MAX_CURL_TIME" -X POST -H 'Content-type: application/json' --data '{"text":"'"$message"'"}' "$SLACK_WEBHOOK_URL" 2>&1)

    # Check the response for errors
    if [ $? -ne 0 ]; then
        echo "$(date): Error sending Slack notification: $response" >> "$LOG_FILE"
    else
        echo "$(date): Slack notification sent successfully." >> "$LOG_FILE"
    fi
}

# Function to perform initial subdomain enumeration using Subfinder
initial_subdomain_enum() {
    send_slack_notification "Performing initial subdomain enumeration..."
    
    for domain in "${TARGET_DOMAINS[@]}"; do
        # Run Subfinder with the target domain and store the output in the log file
        subfinder_output=$(subfinder -d "$domain" -silent)
        # Include the domain itself in the list
        echo "$domain" >> "$DOMAINS_DIR/$domain.txt"
        echo "Initial subdomain enumeration complete for $domain."

        # Build Slack notification message for initial subdomain enumeration
        notification_message="Initial subdomain enumeration complete for $domain.\n\nSubdomains:\n$subfinder_output"

        # Send Slack notification
        send_slack_notification "$notification_message"
    done

    # Run Nuclei after initial subdomain enumeration
    run_nuclei_after_enum
}

# Function to run Nuclei on the discovered subdomains after enumeration
run_nuclei_after_enum() {
    for domain in $(echo "${TARGET_DOMAINS[@]}" | tr ' ' '\n' | sort); do
        # Check if the domain has been scanned
        if [ ! -f "$LOG_FILE" ] || ! grep -q "$domain" "$LOG_FILE"; then
            # Create a directory for the domain's Nuclei output
            DOMAIN_NUCLEI_DIR="$NUCLEI_OUTPUT_DIR/$domain-nuclei_output"
            mkdir -p "$DOMAIN_NUCLEI_DIR"

            # Run Nuclei with the target domain and all available templates
            nuclei -l "$DOMAINS_DIR/$domain.txt" -o "$DOMAIN_NUCLEI_DIR/$domain-nuclei.txt"
            local nuclei_exit_code=$?

            # Check if the Nuclei command completed successfully
            if [ $nuclei_exit_code -eq 0 ]; then
                echo "Nuclei scan complete for $domain."

                # Process Nuclei results and send Slack notification
                process_nuclei_results "$DOMAIN_NUCLEI_DIR" "$domain"

                # Log the scanned domain
                echo "$(date): $domain" >> "$LOG_FILE"
            else
                # If Nuclei command failed, print an error message
                echo "$(date): Error running Nuclei for $domain. Exit code: $nuclei_exit_code" >> "$LOG_FILE"
            fi

            # Record the scanned subdomains for the domain
            record_scanned_subdomains "$domain"

            # Sleep for 3 seconds before proceeding to the next domain
            sleep 3
        fi
    done

    # Proceed to subdomain monitoring
    monitor_subdomains
}

# Function to run Nuclei on new subdomains discovered during monitoring
run_nuclei_on_new_subdomains() {
    for domain in "${TARGET_DOMAINS[@]}"; do
        # Check for new subdomains files (n1-domain.txt, n2-domain.txt, etc.)
        n_files=("$DOMAINS_DIR/$domain"-n*.txt)

        # Iterate through each new subdomains file
        for n_file in "${n_files[@]}"; do
            # Extract the file number (e.g., n1, n2, etc.)
            file_number=$(basename "$n_file" | cut -f1 -d-)

            # Create a directory for the Nuclei output corresponding to the new subdomains file
            output_dir="$NUCLEI_OUTPUT_DIR/$domain-nuclei_output/$file_number"
            mkdir -p "$output_dir"

            # Run Nuclei with the new subdomains and all available templates
            nuclei -l "$n_file" -o "$output_dir/$domain-nuclei.txt"
            local nuclei_exit_code=$?

            # Check if the Nuclei command completed successfully
            if [ $nuclei_exit_code -eq 0 ]; then
                echo "Nuclei scan complete for $domain ($file_number)."

                # Process Nuclei results and send Slack notification
                process_nuclei_results "$output_dir" "$domain"
            else
                # If Nuclei command failed, print an error message
                echo "Error running Nuclei for $domain ($file_number). Exit code: $nuclei_exit_code" >> "$LOG_FILE"
            fi

            # Record the scanned subdomains for the domain
            record_scanned_subdomains "$domain"

            # Sleep for 3 seconds before proceeding to the next domain
            sleep 3
        done
    done
}

# Function to record scanned subdomains for a domain
record_scanned_subdomains() {
    local domain="$1"
    local scanned_subdomains_file="$SCANNED_SUBDOMAINS_DIR/$domain-scanned-subdomains.txt"

    # Extract subdomains from the Nuclei output
    subdomains=$(grep -Eo '[a-zA-Z0-9.-]+\.com' "$DOMAIN_NUCLEI_DIR/$domain-nuclei.txt")

    # Record scanned subdomains in a file
    echo "$subdomains" >> "$scanned_subdomains_file"

    echo "Scanned subdomains recorded for $domain."
}

# Function to process Nuclei results and send Slack notification
process_nuclei_results() {
    local output_folder="$1"
    local domain="$2"

    # Check if the Nuclei output file exists
    if [ -s "$output_folder/$domain-nuclei.txt" ]; then
        # Count vulnerabilities for each severity level
        info_vulns=$(grep -ci "info" "$output_folder/$domain-nuclei.txt")
        low_vulns=$(grep -ci "low" "$output_folder/$domain-nuclei.txt")
        medium_vulns=$(grep -ci "medium" "$output_folder/$domain-nuclei.txt")
        high_vulns=$(grep -ci "high" "$output_folder/$domain-nuclei.txt")
        critical_vulns=$(grep -ci "critical" "$output_folder/$domain-nuclei.txt")

        # Set the prefixes for each severity level
        info_prefix="p5"
        low_prefix="p4"
        medium_prefix="p3"
        high_prefix="p2"
        critical_prefix="p1"

        # Create output files with appropriate prefixes
        info_output_file="$output_folder/$info_prefix-$domain-nuclei.txt"
        low_output_file="$output_folder/$low_prefix-$domain-nuclei.txt"
        medium_output_file="$output_folder/$medium_prefix-$domain-nuclei.txt"
        high_output_file="$output_folder/$high_prefix-$domain-nuclei.txt"
        critical_output_file="$output_folder/$critical_prefix-$domain-nuclei.txt"

        # Move the Nuclei output file to the appropriate file based on severity
        mv "$output_folder/$domain-nuclei.txt" "$info_output_file"

        # Display the counts for each severity level
        echo "Info: $info_vulns vulnerabilities (Saved in: $info_output_file)"
        echo "Low: $low_vulns vulnerabilities (Saved in: $low_output_file)"
        echo "Medium: $medium_vulns vulnerabilities (Saved in: $medium_output_file)"
        echo "High: $high_vulns vulnerabilities (Saved in: $high_output_file)"
        echo "Critical: $critical_vulns vulnerabilities (Saved in: $critical_output_file)"

        # Build Slack notification message
        notification_message="Nuclei scan results for $domain:\n"
        notification_message+="Info: $info_vulns (Saved in: $info_output_file)\n"
        notification_message+="Low: $low_vulns (Saved in: $low_output_file)\n"
        notification_message+="Medium: $medium_vulns (Saved in: $medium_output_file)\n"
        notification_message+="High: $high_vulns (Saved in: $high_output_file)\n"
        notification_message+="Critical: $critical_vulns (Saved in: $critical_output_file)"

        # Send Slack notification
        send_slack_notification "$notification_message"
    else
        # If Nuclei output is empty, print a message
        echo "No Nuclei output found for $domain ($output_folder)."
    fi

    # Run Nuclei on new subdomains
    run_nuclei_on_new_subdomains
}

# Function to monitor for new subdomains
monitor_subdomains() {
    while true; do
        for domain in $(echo "${TARGET_DOMAINS[@]}" | tr ' ' '\n' | sort); do
            # Run both Amass and Subfinder to check for new subdomains
            local amass_output
            amass_output="$(amass enum -d "$domain" -silent 2>&1)"
            local amass_exit_code=$?

            local subfinder_output
            subfinder_output="$(subfinder -d "$domain" -silent 2>&1)"
            local subfinder_exit_code=$?

            # Combine the outputs of Amass and Subfinder
            local new_output="$amass_output"$'\n'"$subfinder_output"

            # Check if there are new subdomains
            if [ $amass_exit_code -eq 0 ] || [ $subfinder_exit_code -eq 0 ]; then
                # Compare with existing subdomains from domain.txt
                diff_result=$(comm -13 <(sort "$DOMAINS_DIR/$domain.txt") <(echo "$new_output" | sort))

                # Check if there are new subdomains
                if [ -n "$diff_result" ]; then
                    # Print and log the new subdomains
                    echo "New subdomains found for $domain:"
                    echo "$diff_result"
                    # Save new subdomains in n1-domain.txt, n2-domain.txt, etc.
                    n_file="$DOMAINS_DIR/$domain"
                    i=1
                    while [ -e "$n_file-n${i}.txt" ]; do
                        i=$((i+1))
                    done
                    n_file="$n_file-n${i}.txt"
                    echo "$diff_result" > "$n_file"
                    echo "New subdomains saved in $n_file"
                    # Append the new subdomains to domain.txt
                    echo "$diff_result" >> "$DOMAINS_DIR/$domain.txt"
                    echo "$domain.txt updated."
                    # Run Nuclei on the new subdomains
                    run_nuclei_on_new_subdomains
                else
                    # If no new subdomains, print a message
                    echo "No new subdomains found for $domain."
                    # Sleep for 3 seconds before the next iteration
                    sleep 3
                fi
            else
                # If Amass or Subfinder failed, print an error message
                echo "$(date): Error running Amass or Subfinder for $domain. Amass exit code: $amass_exit_code, Subfinder exit code: $subfinder_exit_code" >> "$LOG_FILE"
                # Sleep for 3 seconds before the next iteration
                sleep 3
            fi
        done
    done
}

# Check if the domains directory exists, if not, create it
if [ ! -d "$DOMAINS_DIR" ]; then
    mkdir -p "$DOMAINS_DIR"
fi

# Check if the Nuclei output directory exists, if not, create it
if [ ! -d "$NUCLEI_OUTPUT_DIR" ]; then
    mkdir -p "$NUCLEI_OUTPUT_DIR"
fi

# Check if the scanned subdomains directory exists, if not, create it
if [ ! -d "$SCANNED_SUBDOMAINS_DIR" ]; then
    mkdir -p "$SCANNED_SUBDOMAINS_DIR"
fi

# Check if the domains directory is empty, if yes, perform initial enumeration
if [ -z "$(ls -A "$DOMAINS_DIR")" ]; then
    # Notify when initial subdomain enumeration starts
    send_slack_notification "Performing initial subdomain enumeration..."
    initial_subdomain_enum
else
    # Domains directory is not empty, check if all domains have been scanned by Nuclei
    check_all_domains_scanned
fi
