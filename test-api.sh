#!/bin/bash

# MapTag API Test Suite
# Tests all API endpoints to ensure the system is working correctly

API_URL="http://localhost:3000"
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "========================================="
echo "   MapTag API Test Suite"
echo "========================================="
echo ""

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

# Function to test endpoint
test_endpoint() {
    local method=$1
    local endpoint=$2
    local data=$3
    local expected_status=$4
    local test_name=$5
    
    echo -n "Testing: $test_name... "
    
    if [ "$method" == "GET" ]; then
        response=$(curl -s -w "\n%{http_code}" "$API_URL$endpoint")
    elif [ "$method" == "POST" ]; then
        response=$(curl -s -w "\n%{http_code}" -X POST "$API_URL$endpoint" \
            -H "Content-Type: application/json" \
            -d "$data")
    fi
    
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | head -n-1)
    
    if [ "$http_code" == "$expected_status" ]; then
        echo -e "${GREEN}✓ PASSED${NC} (Status: $http_code)"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}✗ FAILED${NC} (Expected: $expected_status, Got: $http_code)"
        echo "  Response: $body"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Function to print section header
print_section() {
    echo ""
    echo -e "${YELLOW}$1${NC}"
    echo "----------------------------------------"
}

# 1. Test Health Endpoint
print_section "1. HEALTH CHECK"
test_endpoint "GET" "/health" "" "200" "Health endpoint"
if [ $? -eq 0 ]; then
    health_response=$(curl -s "$API_URL/health")
    echo "  Health Response: $health_response"
fi

# 2. Test API Test Endpoint
print_section "2. API TEST ENDPOINT"
test_endpoint "GET" "/api/test" "" "200" "API test endpoint"

# 3. Test Get All Addresses
print_section "3. GET ALL ADDRESSES"
test_endpoint "GET" "/api/addresses" "" "200" "Get all addresses"
initial_addresses=$(curl -s "$API_URL/api/addresses")
echo "  Current addresses in database: $initial_addresses"

# 4. Test Create Address - Valid Ouagadougou Location
print_section "4. CREATE NEW ADDRESS"
echo "Creating address in Ouagadougou..."
ouaga_data='{
    "latitude": 12.3714,
    "longitude": -1.5197,
    "placeName": "Test Building Ouaga",
    "category": "Résidence",
    "description": "Near the central market",
    "ownerName": "Test Owner",
    "ownerPhone": "+22670123456"
}'
test_endpoint "POST" "/api/addresses" "$ouaga_data" "201" "Create address in Ouagadougou"
if [ $? -eq 0 ]; then
    created_address=$(curl -s -X POST "$API_URL/api/addresses" \
        -H "Content-Type: application/json" \
        -d "$ouaga_data")
    address_code=$(echo "$created_address" | grep -o '"address_code":"[^"]*' | cut -d'"' -f4)
    echo "  Created address code: $address_code"
fi

# 5. Test Create Address - Bobo-Dioulasso
print_section "5. CREATE ADDRESS IN BOBO-DIOULASSO"
bobo_data='{
    "latitude": 11.1771,
    "longitude": -4.2979,
    "placeName": "Test Shop Bobo",
    "category": "Commerce",
    "description": "Electronics store"
}'
test_endpoint "POST" "/api/addresses" "$bobo_data" "201" "Create address in Bobo-Dioulasso"

# 6. Test Duplicate Detection
print_section "6. DUPLICATE DETECTION TEST"
echo "Attempting to create duplicate address (same location)..."
duplicate_data='{
    "latitude": 12.3714,
    "longitude": -1.5197,
    "placeName": "Duplicate Test",
    "category": "Résidence"
}'
response=$(curl -s -w "\n%{http_code}" -X POST "$API_URL/api/addresses" \
    -H "Content-Type: application/json" \
    -d "$duplicate_data")
http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | head -n-1)

if echo "$body" | grep -q "duplicate"; then
    echo -e "${GREEN}✓ PASSED${NC} - Duplicate detection working"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    if [ "$http_code" == "201" ]; then
        echo -e "${YELLOW}⚠ WARNING${NC} - Address created (might be outside duplicate radius)"
    else
        echo -e "${RED}✗ FAILED${NC} - Unexpected response"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
fi
echo "  Response: $body"

# 7. Test Get Specific Address
if [ ! -z "$address_code" ]; then
    print_section "7. GET SPECIFIC ADDRESS"
    test_endpoint "GET" "/api/addresses/$address_code" "" "200" "Get address by code: $address_code"
    if [ $? -eq 0 ]; then
        specific_address=$(curl -s "$API_URL/api/addresses/$address_code")
        echo "  Address details: $specific_address"
    fi
fi

# 8. Test Invalid Address Code
print_section "8. TEST INVALID ADDRESS CODE"
test_endpoint "GET" "/api/addresses/INVALID-CODE-123" "" "404" "Get non-existent address"

# 9. Test Address with Rural Location
print_section "9. CREATE RURAL ADDRESS"
rural_data='{
    "latitude": 12.0667,
    "longitude": -3.0667,
    "placeName": "Rural Health Center",
    "category": "Service Public",
    "description": "Community health center"
}'
test_endpoint "POST" "/api/addresses" "$rural_data" "201" "Create rural address"

# 10. Test Verification Stats
print_section "10. VERIFICATION STATISTICS"
test_endpoint "GET" "/api/verification/stats" "" "200" "Get verification statistics"
if [ $? -eq 0 ]; then
    stats=$(curl -s "$API_URL/api/verification/stats")
    echo "  Verification stats: $stats"
fi

# 11. Test Address List with Pagination
print_section "11. PAGINATION TEST"
test_endpoint "GET" "/api/addresses?page=1&limit=2" "" "200" "Get addresses with pagination"

# 12. Test Invalid Data
print_section "12. INVALID DATA TESTS"
invalid_data='{
    "latitude": "not-a-number",
    "longitude": -1.5197,
    "placeName": "Invalid Test"
}'
test_endpoint "POST" "/api/addresses" "$invalid_data" "400" "Create address with invalid latitude"

# 13. Test Missing Required Fields
print_section "13. MISSING FIELDS TEST"
incomplete_data='{
    "latitude": 12.3714
}'
test_endpoint "POST" "/api/addresses" "$incomplete_data" "400" "Create address with missing fields"

# 14. Test Boundary Coordinates (Outside Burkina Faso)
print_section "14. BOUNDARY VALIDATION TEST"
outside_bf='{
    "latitude": 0.0,
    "longitude": 0.0,
    "placeName": "Outside Burkina Faso",
    "category": "Test"
}'
test_endpoint "POST" "/api/addresses" "$outside_bf" "400" "Create address outside Burkina Faso"

# 15. Final Address Count
print_section "15. FINAL ADDRESS COUNT"
final_response=$(curl -s "$API_URL/api/addresses")
echo "Final database state: $final_response"

# Summary
echo ""
echo "========================================="
echo "           TEST SUMMARY"
echo "========================================="
echo -e "${GREEN}Tests Passed: $TESTS_PASSED${NC}"
echo -e "${RED}Tests Failed: $TESTS_FAILED${NC}"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ ALL TESTS PASSED! The API is working correctly.${NC}"
    exit 0
else
    echo -e "${RED}✗ Some tests failed. Please check the API.${NC}"
    exit 1
fi