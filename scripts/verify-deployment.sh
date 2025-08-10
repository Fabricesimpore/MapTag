#!/bin/bash

# MapTag BF Deployment Verification Script
set -e

echo "🔍 MapTag BF Deployment Verification"
echo "===================================="

# Configuration
BASE_URL=${1:-http://localhost:3000}
echo "Testing API at: $BASE_URL"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to test endpoint
test_endpoint() {
    local method=$1
    local endpoint=$2
    local expected_status=$3
    local description=$4
    local data=$5

    echo -n "Testing $description... "
    
    if [[ "$method" == "POST" ]]; then
        response=$(curl -s -w "HTTPSTATUS:%{http_code}" -X POST \
            -H "Content-Type: application/json" \
            -d "$data" \
            "$BASE_URL$endpoint" || echo "HTTPSTATUS:000")
    else
        response=$(curl -s -w "HTTPSTATUS:%{http_code}" \
            "$BASE_URL$endpoint" || echo "HTTPSTATUS:000")
    fi
    
    status=$(echo "$response" | grep -o 'HTTPSTATUS:[0-9]*' | sed 's/HTTPSTATUS://')
    body=$(echo "$response" | sed 's/HTTPSTATUS:[0-9]*$//')
    
    if [[ "$status" == "$expected_status" ]]; then
        echo -e "${GREEN}✅ PASS${NC} (HTTP $status)"
        return 0
    else
        echo -e "${RED}❌ FAIL${NC} (HTTP $status, expected $expected_status)"
        if [[ ${#body} -lt 200 ]]; then
            echo "   Response: $body"
        fi
        return 1
    fi
}

# Function to test JSON response
test_json_response() {
    local endpoint=$1
    local description=$2
    local expected_field=$3

    echo -n "Testing $description... "
    
    response=$(curl -s "$BASE_URL$endpoint" || echo "{}")
    
    if echo "$response" | jq -e ".$expected_field" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ PASS${NC}"
        return 0
    else
        echo -e "${RED}❌ FAIL${NC}"
        echo "   Expected field '$expected_field' not found in response"
        return 1
    fi
}

echo "🏥 Health Checks"
echo "----------------"

# Test basic endpoints
test_endpoint "GET" "/health" "200" "Health endpoint"
test_endpoint "GET" "/api/test" "200" "API test endpoint"
test_endpoint "GET" "/api/addresses" "200" "Address list endpoint"
test_endpoint "GET" "/api/verification/stats" "200" "Statistics endpoint"

echo ""
echo "📊 JSON Response Validation"  
echo "---------------------------"

# Test JSON structure
test_json_response "/health" "Health JSON structure" "status"
test_json_response "/api/addresses" "Address list JSON structure" "addresses"
test_json_response "/api/verification/stats" "Statistics JSON structure" "statistics"

echo ""
echo "✏️  Create/Update Operations"
echo "---------------------------"

# Test address creation
test_endpoint "POST" "/api/addresses" "201" "Address creation" \
    '{"latitude": 12.3714, "longitude": -1.5197, "placeName": "Test Address Verification", "category": "Test"}'

echo ""
echo "🎯 Specific Functionality Tests"
echo "-------------------------------"

# Test specific address retrieval (if sample data exists)
echo -n "Testing specific address retrieval... "
sample_code=$(curl -s "$BASE_URL/api/addresses" | jq -r '.addresses[0].code // empty' 2>/dev/null)
if [[ -n "$sample_code" && "$sample_code" != "null" ]]; then
    test_endpoint "GET" "/api/addresses/$sample_code" "200" "Get specific address"
else
    echo -e "${YELLOW}⚠️  SKIP${NC} (No sample addresses found)"
fi

# Test 404 handling
test_endpoint "GET" "/api/addresses/NON-EXISTENT-CODE" "404" "404 error handling"

echo ""
echo "🐳 Docker Services Check"
echo "------------------------"

if command -v docker-compose &> /dev/null; then
    echo -n "Checking Docker services... "
    
    # Check if docker-compose.yml exists
    if [[ -f "docker-compose.yml" ]]; then
        services_up=$(docker-compose ps --services --filter status=running 2>/dev/null | wc -l)
        total_services=$(docker-compose ps --services 2>/dev/null | wc -l)
        
        if [[ $services_up -eq $total_services ]] && [[ $services_up -gt 0 ]]; then
            echo -e "${GREEN}✅ PASS${NC} ($services_up/$total_services services running)"
        else
            echo -e "${RED}❌ FAIL${NC} ($services_up/$total_services services running)"
        fi
    else
        echo -e "${YELLOW}⚠️  SKIP${NC} (docker-compose.yml not found)"
    fi
else
    echo -e "${YELLOW}⚠️  SKIP${NC} (docker-compose not available)"
fi

echo ""
echo "📈 Performance Check"
echo "-------------------"

echo -n "Testing API response time... "
start_time=$(date +%s%N)
curl -s "$BASE_URL/health" > /dev/null
end_time=$(date +%s%N)
duration=$(( (end_time - start_time) / 1000000 ))

if [[ $duration -lt 1000 ]]; then
    echo -e "${GREEN}✅ EXCELLENT${NC} (${duration}ms)"
elif [[ $duration -lt 2000 ]]; then
    echo -e "${GREEN}✅ GOOD${NC} (${duration}ms)"
elif [[ $duration -lt 5000 ]]; then
    echo -e "${YELLOW}⚠️  ACCEPTABLE${NC} (${duration}ms)"
else
    echo -e "${RED}❌ SLOW${NC} (${duration}ms)"
fi

echo ""
echo "📋 Summary"
echo "----------"

# Run final test count
total_tests=0
passed_tests=0

# Re-run critical tests for summary
tests=(
    "GET:/health:200"
    "GET:/api/addresses:200"
    "GET:/api/verification/stats:200"
    "POST:/api/addresses:201"
)

for test in "${tests[@]}"; do
    IFS=':' read -r method endpoint expected <<< "$test"
    ((total_tests++))
    
    if [[ "$method" == "POST" ]]; then
        status=$(curl -s -w "%{http_code}" -o /dev/null -X POST \
            -H "Content-Type: application/json" \
            -d '{"latitude": 12.3714, "longitude": -1.5197, "placeName": "Summary Test", "category": "Test"}' \
            "$BASE_URL$endpoint")
    else
        status=$(curl -s -w "%{http_code}" -o /dev/null "$BASE_URL$endpoint")
    fi
    
    if [[ "$status" == "$expected" ]]; then
        ((passed_tests++))
    fi
done

echo "Tests passed: $passed_tests/$total_tests"

if [[ $passed_tests -eq $total_tests ]]; then
    echo -e "${GREEN}🎉 ALL TESTS PASSED! MapTag BF is ready for production.${NC}"
    exit 0
elif [[ $passed_tests -gt $((total_tests / 2)) ]]; then
    echo -e "${YELLOW}⚠️  PARTIAL SUCCESS. Some issues detected but core functionality works.${NC}"
    exit 1
else
    echo -e "${RED}❌ MULTIPLE FAILURES. Please check your deployment.${NC}"
    exit 2
fi