#!/bin/bash

# MapTag BF Monitoring and Health Check Script
set -e

echo "📊 MapTag BF System Monitoring"
echo "=============================="

# Configuration
API_URL=${API_URL:-http://localhost:3000}
ALERT_EMAIL=${ALERT_EMAIL:-admin@maptag.bf}
LOG_FILE=${LOG_FILE:-./logs/monitoring.log}

# Create logs directory
mkdir -p "$(dirname "$LOG_FILE")"

# Function to log with timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Function to check service health
check_service() {
    local service=$1
    local url=$2
    local expected=$3
    
    log "Checking $service..."
    
    response=$(curl -s -o /dev/null -w "%{http_code}" "$url" || echo "000")
    
    if [[ "$response" == "$expected" ]]; then
        log "✅ $service: OK (HTTP $response)"
        return 0
    else
        log "❌ $service: FAILED (HTTP $response)"
        return 1
    fi
}

# Function to check database
check_database() {
    log "Checking database connection..."
    
    response=$(curl -s "$API_URL/api/verification/stats" | jq -r '.success' 2>/dev/null || echo "false")
    
    if [[ "$response" == "true" ]]; then
        log "✅ Database: Connected"
        return 0
    else
        log "❌ Database: Connection failed"
        return 1
    fi
}

# Function to check Docker services
check_docker_services() {
    log "Checking Docker services..."
    
    local services=("maptag-postgres" "maptag-redis" "maptag-backend")
    local failed_services=()
    
    for service in "${services[@]}"; do
        if docker ps --format "table {{.Names}}\t{{.Status}}" | grep -q "$service.*Up"; then
            log "✅ Docker service $service: Running"
        else
            log "❌ Docker service $service: Not running"
            failed_services+=("$service")
        fi
    done
    
    if [[ ${#failed_services[@]} -eq 0 ]]; then
        return 0
    else
        log "Failed services: ${failed_services[*]}"
        return 1
    fi
}

# Function to check system resources
check_resources() {
    log "Checking system resources..."
    
    # Check disk space
    disk_usage=$(df -h / | tail -1 | awk '{print $5}' | sed 's/%//')
    if [[ $disk_usage -gt 80 ]]; then
        log "⚠️  High disk usage: ${disk_usage}%"
    else
        log "✅ Disk usage: ${disk_usage}%"
    fi
    
    # Check memory usage
    memory_usage=$(free | grep Mem | awk '{printf "%.1f", $3/$2 * 100.0}')
    if [[ $(echo "$memory_usage > 80" | bc -l) -eq 1 ]]; then
        log "⚠️  High memory usage: ${memory_usage}%"
    else
        log "✅ Memory usage: ${memory_usage}%"
    fi
    
    # Check load average
    load_avg=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')
    log "ℹ️  Load average: $load_avg"
}

# Function to get API statistics
get_api_stats() {
    log "Getting API statistics..."
    
    stats=$(curl -s "$API_URL/api/verification/stats" 2>/dev/null || echo "{}")
    
    if [[ "$stats" != "{}" ]]; then
        total_addresses=$(echo "$stats" | jq -r '.statistics.total_addresses // 0')
        verified_addresses=$(echo "$stats" | jq -r '.statistics.verification.verified // 0')
        verification_rate=$(echo "$stats" | jq -r '.statistics.verification_rate // 0')
        
        log "📈 Total addresses: $total_addresses"
        log "📈 Verified addresses: $verified_addresses"
        log "📈 Verification rate: ${verification_rate}%"
    else
        log "❌ Could not retrieve API statistics"
    fi
}

# Function to send alert
send_alert() {
    local subject="$1"
    local message="$2"
    
    log "🚨 ALERT: $subject"
    log "$message"
    
    # If mail is available, send email alert
    if command -v mail >/dev/null 2>&1; then
        echo "$message" | mail -s "$subject" "$ALERT_EMAIL"
        log "📧 Alert email sent to $ALERT_EMAIL"
    fi
    
    # You can add other alerting mechanisms here (Slack, Discord, etc.)
}

# Main monitoring function
run_monitoring() {
    log "Starting monitoring check..."
    
    local failed_checks=0
    
    # Health check
    if ! check_service "API Health" "$API_URL/health" "200"; then
        ((failed_checks++))
    fi
    
    # Database check
    if ! check_database; then
        ((failed_checks++))
    fi
    
    # Docker services check
    if ! check_docker_services; then
        ((failed_checks++))
    fi
    
    # System resources check
    check_resources
    
    # API statistics
    get_api_stats
    
    log "Monitoring check completed. Failed checks: $failed_checks"
    
    if [[ $failed_checks -gt 0 ]]; then
        send_alert "MapTag BF Service Issues Detected" "MapTag BF monitoring detected $failed_checks failed checks. Please check the system."
        return 1
    else
        log "✅ All systems operational"
        return 0
    fi
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  monitor    - Run full monitoring check (default)"
    echo "  health     - Check API health only"
    echo "  database   - Check database only"
    echo "  docker     - Check Docker services only"
    echo "  resources  - Check system resources only"
    echo "  stats      - Show API statistics only"
    echo "  continuous - Run monitoring continuously (every 5 minutes)"
    echo "  help       - Show this help"
}

# Main script logic
case "${1:-monitor}" in
    "monitor")
        run_monitoring
        ;;
    "health")
        check_service "API Health" "$API_URL/health" "200"
        ;;
    "database")
        check_database
        ;;
    "docker")
        check_docker_services
        ;;
    "resources")
        check_resources
        ;;
    "stats")
        get_api_stats
        ;;
    "continuous")
        log "Starting continuous monitoring (every 5 minutes)..."
        while true; do
            run_monitoring
            echo ""
            sleep 300  # 5 minutes
        done
        ;;
    "help")
        show_usage
        ;;
    *)
        echo "Unknown command: $1"
        show_usage
        exit 1
        ;;
esac