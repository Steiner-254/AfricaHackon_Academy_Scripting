# Subdomain Enumeration and Monitoring Script with Nuclei Integration

This Bash script is designed for subdomain enumeration, monitoring, and vulnerability scanning using Subfinder + Amass and Nuclei. The script sends notifications to a Slack channel at various stages of the process.

## Features

- **Initial Subdomain Enumeration**: Uses Subfinder + Amass to perform the initial subdomain enumeration and notifies Slack with a list of discovered subdomains.

- **Nuclei Scans on Discovered Subdomains**: Runs Nuclei scans on discovered subdomains with severity levels (low, medium, high, critical) and notifies Slack with detailed results.

- **Monitoring for New Subdomains**: Monitors for new subdomains and automatically runs Nuclei scans on newly discovered subdomains. Notifies Slack with the results.

- **Slack Notifications**: Sends notifications to Slack at key events, including initial enumeration, Nuclei scan starts, and scan results.

## Prerequisites

- [Subfinder](https://github.com/projectdiscovery/subfinder)
- [Amass](https://github.com/owasp-amass/amass)
- [Nuclei](https://github.com/projectdiscovery/nuclei)
- [Curl](https://curl.se/)

## Configuration

Before running the script, configure the following variables at the beginning of the script:

- `TARGET_DOMAINS`: Array of target domains.
- `SLACK_WEBHOOK_URL`: Slack webhook URL for receiving notifications.
- `MAX_CURL_TIME`: Maximum time for the Curl command (in seconds).

## Usage

1. **Install Required Tools**: Install Subfinder, Amass, Nuclei, and Curl.

2. **Configure the Script**: Set up the script with your target domains and Slack webhook URL.

3. **Run the Script**:

   ```bash
   ./bravo.sh

# Monitor Progress: 

>> Follow the script's progress in the terminal and receive Slack notifications for key events.


# Notifications

>> Initial Subdomain Enumeration: Notifies when the initial subdomain enumeration process starts and provides a list of discovered subdomains.

>> Nuclei Scan Start: Notifies when any Nuclei scan starts, including whether it's an initial scan or a scan on newly discovered subdomains.

>> Nuclei Scan Results: Provides detailed results of Nuclei scans, including vulnerability counts for each severity level. Sends this information to Slack.

>> Monitoring for New Subdomains: Notifies when the script enters the monitoring phase for new subdomains.


# Notes

>> The script uses a Slack webhook for notifications. Set up a Slack app with an incoming webhook and obtain the webhook URL.

>> Customize the script based on your specific requirements.

chmod +x bravo.sh

./bravo.sh

# Author
[@Steiner254](https://twitter.com/Steiner254)


>> Happy Hacking :)
