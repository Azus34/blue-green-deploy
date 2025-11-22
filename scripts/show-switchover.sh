#!/bin/bash

################################################################################
# Script: show-switchover.sh
# Descripción: Demuestra visualmente el proceso de switchover Blue-Green
# Uso: ./scripts/show-switchover.sh [blue|green]
# Propósito: Mostrar al profesor el cambio de tráfico entre entornos
################################################################################

set -e

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Parámetro
TARGET=${1:-"blue"}

print_header() {
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}  $1"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
}

print_step() {
    echo -e "${MAGENTA}▶${NC} $1"
}

print_success() {
    echo -e "  ${GREEN}✓${NC} $1"
}

print_info() {
    echo -e "  ${BLUE}ℹ${NC} $1"
}

wait_for_key() {
    echo ""
    echo -e "${YELLOW}[Presiona ENTER para continuar...]${NC}"
    read -r
}

# Validar parámetro
if [ "$TARGET" != "blue" ] && [ "$TARGET" != "green" ]; then
    echo -e "${RED}Error: Usa 'blue' o 'green' como parámetro${NC}"
    echo "Usage: ./scripts/show-switchover.sh [blue|green]"
    exit 1
fi

clear
print_header "🔄 Blue-Green Switchover Demonstration"

print_info "This script will demonstrate switching traffic from one environment to another"

wait_for_key

# FASE 1: ESTADO ACTUAL
print_header "PHASE 1: Current Environment Status"

print_step "Checking current active environment..."
wait 1

current_active=$(grep -E "upstream.*backend" /etc/nginx/conf.d/service.conf | head -1 | sed 's/.*upstream \([^_]*\).*/\1/' || echo "unknown")

echo ""
print_info "Current active environment: $current_active"
echo ""

echo "Container status:"
docker ps -a --format "table {{.Names}}\t{{.Status}}" | grep -E "app-blue|app-green" || echo "  No containers found"

echo ""
echo "Testing health endpoints:"
for port in 3001 3002; do
    env_name=$(if [ $port -eq 3001 ]; then echo "BLUE"; else echo "GREEN"; fi)
    if curl -sf http://127.0.0.1:$port/health >/dev/null 2>&1; then
        print_success "$env_name (port $port) is healthy"
    else
        print_info "$env_name (port $port) not responding"
    fi
done

wait_for_key

# FASE 2: MOSTRAR ARCHIVOS DE CONFIGURACIÓN
print_header "PHASE 2: Nginx Configuration Files"

print_step "Blue configuration (/etc/nginx/conf.d/blue.conf):"
echo ""
head -15 /etc/nginx/conf.d/blue.conf | sed 's/^/  /'
echo "  ..."

echo ""
print_step "Green configuration (/etc/nginx/conf.d/green.conf):"
echo ""
head -15 /etc/nginx/conf.d/green.conf | sed 's/^/  /'
echo "  ..."

echo ""
print_step "Current service configuration:"
echo ""
cat /etc/nginx/conf.d/service.conf | sed 's/^/  /'

wait_for_key

# FASE 3: PROCESO DE SWITCHOVER
print_header "PHASE 3: Switching Traffic to ${TARGET^^}"

print_step "Step 1: Backing up current Nginx configuration..."
cp /etc/nginx/conf.d/service.conf /etc/nginx/conf.d/service.conf.backup
print_success "Backup created"

wait_for_key

print_step "Step 2: Selecting new configuration file..."
if [ "$TARGET" = "blue" ]; then
    source_file="/etc/nginx/conf.d/blue.conf"
    target_message="🔵 BLUE Environment"
else
    source_file="/etc/nginx/conf.d/green.conf"
    target_message="🟢 GREEN Environment"
fi

print_info "Using: $source_file"
wait_for_key

print_step "Step 3: Applying new Nginx configuration..."
echo ""
echo "  New configuration:"
cat "$source_file" | sed 's/^/    /'

cp "$source_file" /etc/nginx/conf.d/service.conf
print_success "Configuration updated"

wait_for_key

print_step "Step 4: Testing Nginx configuration..."
if nginx -t 2>&1 | grep -q "successful"; then
    print_success "Nginx configuration is valid"
else
    echo -e "  ${RED}✗ Configuration test failed${NC}"
    exit 1
fi

wait_for_key

print_step "Step 5: Reloading Nginx service..."
sudo systemctl reload nginx
print_success "Nginx reloaded"

wait_for_key

# FASE 4: VERIFICACIÓN
print_header "PHASE 4: Verification After Switchover"

print_step "Testing new endpoint (5 requests)..."
echo ""
for i in {1..5}; do
    echo -ne "  Request $i: "
    if curl -sf -H "Host: nueva-app.com" http://127.0.0.1 -w "HTTP %{http_code}\n" 2>/dev/null | tail -1; then
        sleep 1
    fi
done

echo ""
print_step "Confirming active environment..."
new_active=$(grep -E "upstream.*backend" /etc/nginx/conf.d/service.conf | head -1 | sed 's/.*upstream \([^_]*\).*/\1/' || echo "unknown")

if [ "$new_active" = "$TARGET" ]; then
    echo -e "  ${GREEN}✓ Successfully switched to ${TARGET^^}${NC}"
else
    echo -e "  ${RED}✗ Switch verification failed${NC}"
fi

echo ""
print_info "Active environment: $new_active"
print_info "Standby environment: $(if [ "$new_active" = "blue" ]; then echo "green"; else echo "blue"; fi)"

wait_for_key

# FASE 5: RESUMEN
print_header "PHASE 5: Switchover Summary"

echo ""
echo -e "${CYAN}Timeline:${NC}"
echo -e "  1. ${YELLOW}[Prepared]${NC}    - Environment ready on ${TARGET^^} (port $(if [ "$TARGET" = "blue" ]; then echo "3001"; else echo "3002"; fi))"
echo -e "  2. ${YELLOW}[Deployed]${NC}    - Docker container running"
echo -e "  3. ${GREEN}[Switched]${NC}    - Traffic redirected via Nginx"
echo -e "  4. ${GREEN}[Verified]${NC}    - New environment responding"
echo -e "  5. ${YELLOW}[Standby]${NC}    - Old environment still running for rollback"

echo ""
echo -e "${MAGENTA}Key Benefits:${NC}"
echo -e "  • ${GREEN}Zero downtime${NC} - Traffic switched instantly"
echo -e "  • ${GREEN}Easy rollback${NC} - Old environment still running"
echo -e "  • ${GREEN}Health monitoring${NC} - Both environments can be tested"
echo -e "  • ${GREEN}Production safe${NC} - Switch without stopping current service"

echo ""
echo -e "${CYAN}Next Steps:${NC}"
echo -e "  • Monitor application logs: ${YELLOW}tail -f /var/log/blue-green-deploy.log${NC}"
echo -e "  • Check Nginx logs: ${YELLOW}sudo tail -f /var/log/nginx/blue-green-error.log${NC}"
echo -e "  • View container logs: ${YELLOW}docker logs app-${TARGET}${NC}"
echo -e "  • Rollback if needed: ${YELLOW}./scripts/switch-to-$(if [ "$TARGET" = "blue" ]; then echo "green"; else echo "blue"; fi).sh${NC}"

wait_for_key

print_header "✅ Switchover Demonstration Complete"

echo ""
echo -e "${GREEN}The demonstration shows how Blue-Green deployment:${NC}"
echo -e "  ✓ Maintains two production environments"
echo -e "  ✓ Switches traffic atomically"
echo -e "  ✓ Allows instant rollback"
echo -e "  ✓ Enables zero-downtime deployments"
echo ""
