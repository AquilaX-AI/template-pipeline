
# AquilaX Security Scan GitHub Action
AquilaX Security Scan is a comprehensive security analysis tool designed to scan your repositories for vulnerabilities, including issues related to sensitive data exposure, insecure configurations, and common coding weaknesses. The AquilaX Security Scan integrates seamlessly into your CI/CD pipeline to automatically check your repository every time you push or open a pull request.
## Why Use AquilaX Security Scan?
- **Automated Security Audits**: Automatically scan your repository for security vulnerabilities every time code is pushed to the main branch or during pull requests.
- **Comprehensive Scanners**: Includes scanners for sensitive data exposure (PII), insecure configurations (IaC), container vulnerabilities, code quality (SAST), and more.
- **SARIF Integration with GitHub Security**: Easily upload scan results in SARIF format to GitHub's security dashboard for detailed insights.
- **Improved Security Posture**: Identify and fix security vulnerabilities early in the development cycle to minimize risks.
- **Customizable**: Allows you to set organization ID, group ID, and various scan configurations to suit your project needs.

## Setup and Configuration
### 1. Add the GitHub Actions YAML File
First, create a new workflow file in your repository. This file will configure the AquilaX Security Scan as part of your CI/CD pipeline.

##### 1. Create a .github/workflows/aquilax-security-scan.yml file.
Add the following content:


```yaml
name: AquilaX Security Scan

on:
  push:
    branches:
      - main
  pull_request:
    branches:
      - main

permissions:
  contents: read
  security-events: write

jobs:
  aquilax_scan:
    runs-on: ubuntu-latest
    timeout-minutes: 60
    steps:
      - name: Checkout repository
        uses: actions/checkout@v3

      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.9'

      - name: Install Dependencies
        run: |
          echo "Installing AquilaX CLI and dependencies..."
          pip install aquilax
          sudo apt-get update && sudo apt-get install -y jq

      - name: Running AquilaX Scan
        id: start_scan
        env:
          AQUILAX_AUTH: ${{ secrets.AQUILAX_API_TOKEN }}
        run: |
          echo "Starting AquilaX Security Scan..."
          aquilax scan \
            --org-id "6691108b1985981c1f5d5b93" \
            --group-id "66cc51d790da713a3f7c6075" \
            --git-uri "https://github.com/AquilaX-AI/vulnapp-python" \
            --scanners sast_scanner iac_scanner secret_scanner pii_scanner sca_scanner container_scanner cicd_scanner \
            --public true \
            --frequency Once \
            --tags cicd audit --format json > scan-output.json

          SCAN_ID=$(jq -r '.scan_id' scan-output.json)
          PROJECT_ID=$(jq -r '.project_id' scan-output.json)
          echo "Scan started with SCAN_ID=$SCAN_ID and PROJECT_ID=$PROJECT_ID"
          echo "SCAN_ID=$SCAN_ID" >> $GITHUB_ENV
          echo "PROJECT_ID=$PROJECT_ID" >> $GITHUB_ENV

      - name: Scan Status
        env:
          AQUILAX_AUTH: ${{ secrets.AQUILAX_API_TOKEN }}
        run: |
          export AQUILAX_AUTH=${{ secrets.AQUILAX_API_TOKEN }}
          max_attempts=20
          sleep_time=5
          attempt=1
          while [ "$attempt" -le "$max_attempts" ]; do
            echo "Fetching scan results..."
            aquilax get-scan-details \
              --org-id "6691108b1985981c1f5d5b93" \
              --group-id "66cc51d790da713a3f7c6075" \
              --project-id "$PROJECT_ID" \
              --scan-id "$SCAN_ID" --format json > scan-results.json

            scan_status=$(jq -r '.scan.status' scan-results.json)
            echo "Current Scan Status: $scan_status"
            
            if [ "$scan_status" = "COMPLETED" ]; then
              echo "Scan completed successfully."
              break
            elif [ "$scan_status" = "FAILED" ]; then
              echo "Scan failed."
              exit 1
            fi

            sleep "$sleep_time"
            sleep_time=$((sleep_time * 2))
            if [ "$sleep_time" -gt 60 ]; then
              sleep_time=60
            fi

            attempt=$((attempt + 1))
          done

          if [ "$scan_status" != "COMPLETED" ]; then
            echo "Scan did not complete within the expected time frame."
            exit 1
          fi

      - name: SARIF Scan Results
        env:
          AQUILAX_AUTH: ${{ secrets.AQUILAX_API_TOKEN }}
        run: |
          echo "Fetching scan results in SARIF format..."
          aquilax get-scan-details \
            --org-id "6691108b1985981c1f5d5b93" \
            --group-id "66cc51d790da713a3f7c6075" \
            --project-id "$PROJECT_ID" \
            --scan-id "$SCAN_ID" --format sarif > results.sarif

          echo "SARIF results:"
          cat results.sarif

      - name: Uploading SARIF to GitHub Security
        uses: github/codeql-action/upload-sarif@v2
        with:
          sarif_file: results.sarif

      - name: Checking for Vulnerabilities
        env:
          AQUILAX_AUTH: ${{ secrets.AQUILAX_API_TOKEN }}
        run: |
          echo "Fetching final scan results..."
          aquilax get-scan-details \
            --org-id "6691108b1985981c1f5d5b93" \
            --group-id "66cc51d790da713a3f7c6075" \
            --project-id "$PROJECT_ID" \
            --scan-id "$SCAN_ID" --format json > final-results.json

          vulnerabilities_count=$(jq '[.scan.results[] | select(.findings != null) | .findings[]] | length' final-results.json)
          echo "::warning::Number of vulnerabilities found: $vulnerabilities_count"
      
          fail_on_vulns=false

          if [ "$fail_on_vulns" = "true" ]; then
            if [ "$vulnerabilities_count" -gt 0 ]; then
              echo "::error::Vulnerabilities found in the scan results!"
              exit 1
            else
              echo "::notice::No vulnerabilities found."
            fi
          else
            echo "::warning::Vulnerabilities found, but pipeline will continue due to 'fail_on_vulns' set to false."
          fi
```
### 2. Set GitHub Secrets
To securely authenticate with AquilaX and prevent exposing sensitive information, set up your secrets in GitHub:

Navigate to your GitHub repository.

Click on **Settings** > **Secrets and Variables** > **Actions**.

Click **New repository secret**.

Add the following secrets:

```AQUILAX_API_TOKEN: The API token for authenticating with AquilaX.```

### 3. Set Organization ID and Group ID
In the YAML file, update the placeholders with your organization ID and group ID:

```yaml
--org-id "your_org_id" \
--group-id "your_group_id"
```

You can find these values from your AquilaX dashboard (app.aquilax.ai) / Aquilax CLI 

```bash
aquilax get-orgs # output is your org id
aquilax get-groups --org-id "org_id"
--git-uri "your_repo_uri" \
--scanners sast_scanner iac_scanner secret_scanner pii_scanner sca_scanner container_scanner cicd_scanner \ # scanners you want to enable
```

Also, you can set 
```bash
fail_on_vulns=false # Vulnerabilities found, but pipeline will continue due to 'fail_on_vulns' set to false else if vulnerabilities are found pipeline will break.
```

## Usage
Once you’ve set up the workflow and secrets:

Run on Push: Every time a new commit is pushed to the main branch, the AquilaX Security Scan will automatically start.
Run on Pull Requests: The scan will also run on pull requests to main, ensuring that no vulnerabilities are introduced through new code changes.

### Benefits of Using AquilaX Security Scan
Automated Security Checks


## Screenshots

![App Screenshot](https://i.pinimg.com/736x/02/45/64/02456463a2f50a33ea1e81deb8bea1b0.jpg)




## Support

For support, email omer@aquilax.ai.


## More Links

 - [Website](https://aquilax.ai)
 - [Dashboard](https://app.aquilax.ai)
 - [Github](https://github.com/AquilaX-AI)

