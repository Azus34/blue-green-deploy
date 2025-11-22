#!/bin/bash

################################################################################
# Script: status-check.sh
# Descripción: Verifica el estado actual del entorno Blue-Green
# Uso: ./scripts/status-check.sh
# Propósito: Mostrar información clara sobre qué entorno está activo
################################################################################

set -e

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Funciones
print_status() {
    printf "${BLUE}%-40s${NC} %s\n" "$1" "$2"
}

print_header() {
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Función para verificar health endpoint
check_health() {
    local port=$1
    local name=$2
    
    if curl -sf http://127.0.0.1:$port/health -w "\n" >/dev/null 2>&1; then
        echo -e "  ${GREEN}✓${NC} $name on port $port: ${GREEN}HEALTHY${NC}"
        return 0
    else
        echo -e "  ${YELLOW}○${NC} $name on port $port: ${YELLOW}NOT RESPONDING${NC}"
        return 1
    fi
}

# Función para obtener versión de aplicación
get_version() {
    local port=$1
    
    curl -sf http://127.0.0.1:$port/version -w "\n" 2>/dev/null || echo "unknown"
}

# Función para detectar entorno activo
get_active_env() {
    if grep -q "blue_backend" /etc/nginx/conf.d/service.conf 2>/dev/null; then
        echo "BLUE"
    elif grep -q "green_backend" /etc/nginx/conf.d/service.conf 2>/dev/null; then
        echo "GREEN"
    else
        echo "UNKNOWN"
    fi
}

# INICIO
clear
print_header "Blue-Green Deployment Status Check"

echo ""
print_status "Timestamp:" "$(date '+%Y-%m-%d %H:%M:%S')"
print_status "Hostname:" "$(hostname)"

echo ""
print_header "Docker Containers Status"
echo ""

docker_output=$(docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || echo "")

if [ -n "$docker_output" ]; then
    echo "$docker_output"
else
    echo -e "${YELLOW}No containers running${NC}"
fi

echo ""
print_header "Environment Health Check"
echo ""

echo -e "${BLUE}Checking BLUE environment (port 3001):${NC}"
blue_healthy=0
check_health 3001 "Blue App" || blue_healthy=$?

echo ""
echo -e "${BLUE}Checking GREEN environment (port 3002):${NC}"
green_healthy=0
check_health 3002 "Green App" || green_healthy=$?

echo ""
print_header "Active Environment"
echo ""

active_env=$(get_active_env)

if [ "$active_env" = "BLUE" ]; then
    echo -e "  ${BLUE}🔵 Current Active Environment: BLUE (Primary)${NC}"
    echo -e "  ${YELLOW}  Standby: GREEN${NC}"
elif [ "$active_env" = "GREEN" ]; then
    echo -e "  ${GREEN}🟢 Current Active Environment: GREEN (Primary)${NC}"
    echo -e "  ${YELLOW}  Standby: BLUE${NC}"
else
    echo -e "  ${RED}❌ Could not determine active environment${NC}"
fi

echo ""
print_header "Nginx Configuration"
echo ""

if sudo test -f /etc/nginx/conf.d/service.conf; then
    echo -e "${BLUE}Active Nginx Service Config:${NC}"
    sudo grep -E "upstream|proxy_pass" /etc/nginx/conf.d/service.conf | head -10
else
    echo -e "${YELLOW}No service.conf found${NC}"
fi

echo ""
echo -e "${BLUE}Available Nginx Configs:${NC}"
ls -lh /etc/nginx/conf.d/*.conf 2>/dev/null | awk '{print "  " $9 " (" $5 ")"}'

echo ""
print_header "Application Endpoint Test"
echo ""

echo -e "${BLUE}Testing main endpoint (via Nginx):${NC}"
if curl -sf -H "Host: nueva-app.com" http://127.0.0.1 -w "HTTP Status: %{http_code}\n" | head -5 > /tmp/curl_test.txt 2>&1; then
    head -3 /tmp/curl_test.txt
    echo -e "  ${GREEN}✓ Endpoint is responding${NC}"
else
    echo -e "  ${YELLOW}○ Endpoint not responding or slow${NC}"
fi

echo ""
print_header "Recent Logs"
echo ""

if [ -f /var/log/blue-green-deploy.log ]; then
    echo -e "${BLUE}Last 15 deployment log entries:${NC}"
    tail -15 /var/log/blue-green-deploy.log | sed 's/^/  /'
else
    echo -e "${YELLOW}No deployment logs found${NC}"
fi

echo ""
print_header "Summary"
echo ""

if [ $blue_healthy -eq 0 ] || [ $green_healthy -eq 0 ]; then
    echo -e "  ${GREEN}✓ At least one environment is healthy${NC}"
else
    echo -e "  ${YELLOW}○ No healthy environments detected${NC}"
fi

if [ "$active_env" != "UNKNOWN" ]; then
    echo -e "  ${GREEN}✓ Active environment is properly configured${NC}"
else
    echo -e "  ${RED}✗ Issue with environment configuration${NC}"
fi

echo ""
print_header "Status Check Complete"
echo ""
echo -e "${CYAN}For more details, check:${NC}"
echo "  - Application logs: tail -f /var/log/blue-green-deploy.log"
echo "  - Nginx logs: sudo tail -f /var/log/nginx/blue-green-error.log"
echo "  - Docker logs: docker logs <container_name>"
echo ""
