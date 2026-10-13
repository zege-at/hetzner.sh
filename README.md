# hetzner.sh

A lightweight, zero-dependency Bash script that automatically updates your dynamic WAN IP address on Hetzner DNS using the **Hetzner Cloud API**.

It is specifically engineered to run reliably on Ubiquiti routing hardware (**UniFi OS** gateways like UCG Ultra/UDM/UXG and **EdgeRouter / EdgeOS**) with full persistence across system firmware upgrades.

---

## Prerequisites

1. **Hetzner Cloud API Token:**
   - Log into [console.hetzner.com](https://console.hetzner.com/).
   - Select your project -> Go to **Security** -> **API Tokens**.
   - Click **Generate API Token** with **Read & Write** permissions.
2. **Hetzner DNS Zone:**
   - Ensure your domain is active under Hetzner DNS.

---

## Installation
### Quick Automated Installation (Recommended)
SSH into your router/gateway or Linux server as root and run the one-line installer:

```
curl -fsSL https://raw.githubusercontent.com/zege-at/hetzner.sh/refs/heads/main/install.sh | bash
```

What the Installer Does:
1. System Detection: Detects if you are running UniFi OS, EdgeOS, or Generic Linux, and selects the proper persistent installation directory (/data/.hetzner.sh, /config/scripts/hetzner, or /opt/hetzner-dyndns).
2. Dependency Check: Verifies that curl and jq are present, automatically installing jq if missing.
3. Interactive Setup: Prompts for your Hetzner API Token, Zone Name (e.g. example.com), and Record Name (e.g. router).
4. Template Download & Config: Downloads hetzner.sh and the template file hetzner.sh.env.example, copies the template to hetzner.sh.env, and updates your credentials via sed.
5. Permissions & Linking: Sets strict file permissions (700 on scripts, 600 on .env) and creates a convenience symlink on UniFi OS (/root/.hetzner.sh).
6. Cron Automation & Initial Run: Configures a 5-minute automated cron task and executes an immediate test run.
