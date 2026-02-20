#!/bin/bash
# TLH System Health Check
# Run: bash scripts/health-check.sh

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=========================================="
echo "  TLH System Health Check"
echo "  $(date)"
echo "=========================================="
echo ""

ERRORS=0

# Function to check HTTP endpoint
check_endpoint() {
    local name=$1
    local url=$2
    local expected=$3

    response=$(curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null || echo "000")

    if [ "$response" == "$expected" ]; then
        echo -e "${GREEN}[PASS]${NC} $name ($url) - HTTP $response"
        return 0
    else
        echo -e "${RED}[FAIL]${NC} $name ($url) - HTTP $response (expected $expected)"
        ERRORS=$((ERRORS + 1))
        return 1
    fi
}

# Function to check JSON response
check_json() {
    local name=$1
    local url=$2
    local jq_filter=$3
    local expected=$4

    response=$(curl -s "$url" 2>/dev/null)
    value=$(echo "$response" | grep -o "\"$jq_filter\":[^,}]*" | cut -d: -f2 | tr -d '"' | tr -d ' ')

    if [ "$value" == "$expected" ]; then
        echo -e "${GREEN}[PASS]${NC} $name - $jq_filter=$value"
        return 0
    else
        echo -e "${RED}[FAIL]${NC} $name - $jq_filter=$value (expected $expected)"
        ERRORS=$((ERRORS + 1))
        return 1
    fi
}

echo "--- Core Services ---"
check_endpoint "Frontend" "http://localhost:3001" "200"
check_endpoint "Prover API Health" "http://localhost:8787/health" "200"
check_endpoint "External Adapter Health" "http://localhost:8788/health" "200"

echo ""
echo "--- API Endpoints ---"
check_endpoint "Frontend /api/verify" "http://localhost:3001/api/verify" "200"
check_endpoint "Prover API /deco/verify" "http://localhost:8787/deco/verify" "200"

echo ""
echo "--- Verification Flow ---"

# Test DECO verification returns PASS
verify_result=$(curl -s "http://localhost:8787/deco/verify" 2>/dev/null)
result=$(echo "$verify_result" | grep -o '"result":"[^"]*"' | cut -d'"' -f4)
if [ "$result" == "PASS" ]; then
    echo -e "${GREEN}[PASS]${NC} DECO Verification - result=PASS"
else
    echo -e "${RED}[FAIL]${NC} DECO Verification - result=$result (expected PASS)"
    ERRORS=$((ERRORS + 1))
fi

# Test GMC lookup
gmc_result=$(curl -s "http://localhost:3001/api/gmc?surname=Adfcds&givenName=Azhar" 2>/dev/null)
found=$(echo "$gmc_result" | grep -o '"found":true' || echo "")
if [ -n "$found" ]; then
    echo -e "${GREEN}[PASS]${NC} GMC Lookup - Doctor found"
else
    echo -e "${RED}[FAIL]${NC} GMC Lookup - Doctor not found"
    ERRORS=$((ERRORS + 1))
fi

echo ""
echo "--- Authentication ---"

# Test EA requires auth
ea_noauth=$(curl -s -X POST "http://localhost:8788/" -H "Content-Type: application/json" -d '{"id":"1"}' 2>/dev/null)
status=$(echo "$ea_noauth" | grep -o '"statusCode":401' || echo "")
if [ -n "$status" ]; then
    echo -e "${GREEN}[PASS]${NC} External Adapter - Rejects unauthenticated requests"
else
    echo -e "${RED}[FAIL]${NC} External Adapter - Should reject unauthenticated requests"
    ERRORS=$((ERRORS + 1))
fi

echo ""
echo "--- Docker Services (Optional) ---"

# Check Docker containers
if command -v docker &> /dev/null; then
    chainlink=$(docker ps --filter "name=chainlink" --format "{{.Names}}" 2>/dev/null | head -1)
    if [ -n "$chainlink" ]; then
        echo -e "${GREEN}[RUNNING]${NC} Chainlink Node"
    else
        echo -e "${YELLOW}[STOPPED]${NC} Chainlink Node (optional for local dev)"
    fi

    validators=$(docker ps --filter "name=tlh-validator" --format "{{.Names}}" 2>/dev/null | wc -l)
    if [ "$validators" -gt 0 ]; then
        echo -e "${GREEN}[RUNNING]${NC} Private Chain ($validators validators)"
    else
        echo -e "${YELLOW}[STOPPED]${NC} Private Chain (optional - using Sepolia)"
    fi
else
    echo -e "${YELLOW}[SKIP]${NC} Docker not installed"
fi

echo ""
echo "=========================================="
if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}All checks passed!${NC}"
    exit 0
else
    echo -e "${RED}$ERRORS check(s) failed${NC}"
    exit 1
fi
