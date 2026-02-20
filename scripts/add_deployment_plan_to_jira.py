#!/usr/bin/env python3
"""
Add TLH Deployment Plan to Jira
Creates Epic and Tasks for the deployment infrastructure
"""

import os
import requests
from requests.auth import HTTPBasicAuth
import time

# Jira Configuration - Token from environment variable
JIRA_URL = "https://pixelette-team-jy6xlpaf.atlassian.net"
JIRA_EMAIL = os.environ.get("JIRA_EMAIL", "partnerships@pixelette.tech")
JIRA_TOKEN = os.environ.get("JIRA_TOKEN", "")  # Set JIRA_TOKEN env var before running
PROJECT_KEY = "TLH"

if not JIRA_TOKEN:
    print("ERROR: JIRA_TOKEN environment variable not set")
    print("Set it with: export JIRA_TOKEN='your-token-here'")
    exit(1)

auth = HTTPBasicAuth(JIRA_EMAIL, JIRA_TOKEN)
headers = {
    "Accept": "application/json",
    "Content-Type": "application/json"
}

def api_call(method, endpoint, data=None):
    """Make API call with retry logic"""
    url = f"{JIRA_URL}{endpoint}"
    for attempt in range(3):
        try:
            if method == "GET":
                response = requests.get(url, headers=headers, auth=auth, timeout=30)
            elif method == "POST":
                response = requests.post(url, headers=headers, auth=auth, json=data, timeout=30)

            if response.status_code in [200, 201, 204]:
                return response.json() if response.text else {}
            elif response.status_code == 400:
                print(f"  Bad Request: {response.text}")
                return None
            else:
                print(f"  Error {response.status_code}: {response.text}")
                return None
        except Exception as e:
            print(f"  Attempt {attempt+1} failed: {e}")
            time.sleep(2)
    return None

def create_issue(summary, issue_type, description="", labels=None):
    """Create a Jira issue"""
    data = {
        "fields": {
            "project": {"key": PROJECT_KEY},
            "summary": summary,
            "issuetype": {"name": issue_type},
            "description": {
                "type": "doc",
                "version": 1,
                "content": [
                    {
                        "type": "paragraph",
                        "content": [{"type": "text", "text": description or summary}]
                    }
                ]
            }
        }
    }

    if labels:
        data["fields"]["labels"] = labels

    result = api_call("POST", "/rest/api/3/issue", data)
    if result:
        print(f"  Created: {result.get('key')} - {summary[:60]}...")
        return result
    return None

# ============================================
# DEPLOYMENT PLAN DATA
# ============================================

EPIC = {
    "name": "EPIC 10: Deployment & Infrastructure",
    "description": """Production deployment infrastructure for TLH platform.

Architecture:
- Frontend: Vercel (Next.js 16)
- Prover API: Render (Express.js)
- External Adapter: Render (Express.js)
- Chainlink Node: Hetzner CX32 (Docker)
- Private Chain: Hetzner CX32 (4x Polygon Edge validators)

Cost Estimate: ~$15-23/month total
- Vercel: $0 (Hobby)
- Render: $7-14 (2 services)
- Hetzner CX32: ~$8.50/month"""
}

STORIES = [
    {
        "summary": "Frontend deployment to Vercel",
        "description": "Deploy Next.js 16 frontend to Vercel with production environment variables",
        "labels": ["deployment", "frontend"]
    },
    {
        "summary": "Backend services deployment to Render",
        "description": "Deploy Prover API and External Adapter to Render as web services",
        "labels": ["deployment", "backend"]
    },
    {
        "summary": "Chainlink Node deployment to Hetzner",
        "description": "Deploy Chainlink Node + PostgreSQL to Hetzner CX32 VPS using Docker Compose",
        "labels": ["deployment", "chainlink", "hetzner"]
    },
    {
        "summary": "Private Chain deployment to Hetzner",
        "description": "Deploy 4-validator Polygon Edge IBFT 2.0 cluster to Hetzner VPS",
        "labels": ["deployment", "private-chain", "hetzner"]
    },
    {
        "summary": "CI/CD pipeline setup",
        "description": "Configure GitHub Actions for automated deployment on push to main",
        "labels": ["deployment", "ci-cd"]
    }
]

TASKS = [
    # Frontend (Vercel)
    {"summary": "Connect TLH-New repo to Vercel", "labels": ["vercel"]},
    {"summary": "Configure NEXT_PUBLIC_PROVER_API_URL env var", "labels": ["vercel"]},
    {"summary": "Configure NEXT_PUBLIC_RPC_URL env var", "labels": ["vercel"]},
    {"summary": "Configure Vercel project settings (Next.js 16)", "labels": ["vercel"]},
    {"summary": "Verify production build on Vercel", "labels": ["vercel"]},

    # Render - Prover API
    {"summary": "Create Render web service for prover-api", "labels": ["render"]},
    {"summary": "Configure prover-api environment variables", "labels": ["render"]},
    {"summary": "Set build command: npm install && npm run build", "labels": ["render"]},
    {"summary": "Set start command: npm start", "labels": ["render"]},
    {"summary": "Verify prover-api health endpoint on Render", "labels": ["render"]},

    # Render - External Adapter
    {"summary": "Create Render web service for external-adapter", "labels": ["render"]},
    {"summary": "Configure external-adapter PROVER_API_URL", "labels": ["render"]},
    {"summary": "Configure external-adapter RPC_URL and PRIVATE_KEY", "labels": ["render"]},
    {"summary": "Verify external-adapter health endpoint on Render", "labels": ["render"]},

    # Hetzner - Setup
    {"summary": "Create Hetzner CX32 server (Ubuntu 24.04)", "labels": ["hetzner"]},
    {"summary": "Install Docker and Docker Compose on Hetzner", "labels": ["hetzner"]},
    {"summary": "Configure firewall (8545, 6688, SSH only)", "labels": ["hetzner"]},
    {"summary": "Create deployment user and SSH keys", "labels": ["hetzner"]},

    # Hetzner - Chainlink Node
    {"summary": "Clone TLH-New repo to Hetzner server", "labels": ["hetzner", "chainlink"]},
    {"summary": "Create chainlink-node/.env with production secrets", "labels": ["hetzner", "chainlink"]},
    {"summary": "Start Chainlink Node docker compose stack", "labels": ["hetzner", "chainlink"]},
    {"summary": "Configure Chainlink job spec for TLH attestations", "labels": ["hetzner", "chainlink"]},
    {"summary": "Verify Chainlink Node UI accessible on :6688", "labels": ["hetzner", "chainlink"]},

    # Hetzner - Private Chain
    {"summary": "Run private-chain/init.sh to generate validator secrets", "labels": ["hetzner", "private-chain"]},
    {"summary": "Start private chain docker compose stack", "labels": ["hetzner", "private-chain"]},
    {"summary": "Verify all 4 validators are sealing blocks", "labels": ["hetzner", "private-chain"]},
    {"summary": "Deploy TrustAttestationVerifier to private chain", "labels": ["hetzner", "private-chain"]},
    {"summary": "Deploy CredentialRegistry to private chain", "labels": ["hetzner", "private-chain"]},

    # CI/CD
    {"summary": "Create .github/workflows/deploy-frontend.yml", "labels": ["ci-cd"]},
    {"summary": "Create .github/workflows/deploy-backend.yml", "labels": ["ci-cd"]},
    {"summary": "Add Vercel token to GitHub secrets", "labels": ["ci-cd"]},
    {"summary": "Add Render API key to GitHub secrets", "labels": ["ci-cd"]},
    {"summary": "Test CI/CD pipeline end-to-end", "labels": ["ci-cd"]},

    # Documentation
    {"summary": "Write DEPLOYMENT.md with step-by-step instructions", "labels": ["docs"]},
    {"summary": "Document environment variables for each service", "labels": ["docs"]},
    {"summary": "Create scripts/deploy-hetzner.sh automation script", "labels": ["docs"]},
]

def main():
    print("=" * 60)
    print("TLH Deployment Plan - Jira Import")
    print("=" * 60)

    # Verify connection
    print("\n1. Verifying Jira connection...")
    user_info = api_call("GET", "/rest/api/3/myself")
    if not user_info:
        print("Failed to connect to Jira. Check credentials.")
        return
    print(f"  Connected as: {user_info['displayName']}")

    # Create Epic
    print("\n2. Creating Deployment Epic...")
    epic = create_issue(EPIC["name"], "Epic", EPIC["description"], ["deployment", "infrastructure"])
    if not epic:
        print("  Failed to create epic. Continuing with stories...")
    else:
        print(f"  Epic created: {epic.get('key')}")

    # Create Stories
    print("\n3. Creating Stories...")
    story_count = 0
    for story in STORIES:
        result = create_issue(story["summary"], "Story", story["description"], story.get("labels", []))
        if result:
            story_count += 1
        time.sleep(0.3)
    print(f"  Created {story_count}/{len(STORIES)} stories")

    # Create Tasks
    print("\n4. Creating Tasks...")
    task_count = 0
    for task in TASKS:
        result = create_issue(task["summary"], "Task", task["summary"], task.get("labels", []))
        if result:
            task_count += 1
        time.sleep(0.3)
    print(f"  Created {task_count}/{len(TASKS)} tasks")

    print("\n" + "=" * 60)
    print("IMPORT COMPLETE!")
    print("=" * 60)
    print(f"Epic: 1")
    print(f"Stories: {story_count}")
    print(f"Tasks: {task_count}")
    print(f"\nView at: {JIRA_URL}/jira/software/projects/{PROJECT_KEY}/boards")

if __name__ == "__main__":
    main()
