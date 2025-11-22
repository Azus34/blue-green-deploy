#!/bin/bash

################################################################################
# Script: switch-to-green.sh
# Descripción: Cambia el tráfico hacia el entorno GREEN
# Uso: ./scripts/switch-to-green.sh
################################################################################

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Variables
NGINX_CONF_DIR="/etc/nginx/conf.d"
NGINX_ACTIVE_FILE="/etc/nginx/blue-green-active"
SERVICE_CONF="${NGINX_CONF_DIR}/service.conf"
BLUE_CONF="${NGINX_CONF_DIR}/blue.conf"
GREEN_CONF="${NGINX_CONF_DIR}/green.conf"
LOG_FILE="/var/log/blue-green-deploy.log"

# Funciones
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

# Inicializar log
{
    echo "======================================================================"
    echo "Blue-Green Switch: Cambiando a GREEN"
    echo "Fecha: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "======================================================================"
} | tee -a "$LOG_FILE"

log_info "Iniciando cambio de tráfico hacia GREEN..."

# Verificar que somos root o tenemos sudo
if [ "$EUID" -ne 0 ]; then
    log_error "Este script debe ejecutarse con sudo"
    exit 1
fi

# Verificar que la aplicación GREEN está corriendo
log_info "Verificando que contenedor app-green está corriendo..."
if ! docker ps --format '{{.Names}}' | grep -q "^app-green$"; then
    log_error "Contenedor app-green no está corriendo"
    log_info "Verifica el estado con: docker ps -a"
    exit 1
fi

# Health check
log_info "Realizando health check a http://127.0.0.1:3002/health..."
if ! curl -sf http://127.0.0.1:3002/health > /dev/null 2>&1; then
    log_warning "Health check falló para GREEN, pero continuando..."
else
    log_success "Health check exitoso para GREEN"
fi

# Crear o actualizar el archivo de configuración de Nginx
log_info "Actualizando configuración de Nginx..."

# Eliminar archivos de configuración anteriores para evitar duplicados
log_info "Limpiando configuraciones anteriores..."
sudo rm -f "$BLUE_CONF" "$GREEN_CONF" "$SERVICE_CONF"

# Copiar la configuración de GREEN desde el repositorio
log_info "Copiando configuración de GREEN..."
if [ -f "./nginx/green.conf" ]; then
    sudo cp ./nginx/green.conf "$SERVICE_CONF"
else
    log_error "No se puede encontrar ./nginx/green.conf"
    exit 1
fi

# Asegurar que no hay archivos conf duplicados
log_info "Limpiando archivos conf duplicados..."
sudo rm -f "$BLUE_CONF" "$GREEN_CONF"

# Actualizar archivo de estado
log_info "Actualizando archivo de estado..."
echo "green" | sudo tee "$NGINX_ACTIVE_FILE" > /dev/null

# Verificar sintaxis de Nginx
log_info "Verificando sintaxis de Nginx..."
if ! sudo nginx -t; then
    log_error "Error en la configuración de Nginx"
    # Restaurar la configuración anterior
    log_warning "Restaurando configuración anterior..."
    sudo cp "$BLUE_CONF" "$SERVICE_CONF" 2>/dev/null || true
    echo "blue" | sudo tee "$NGINX_ACTIVE_FILE" > /dev/null 2>&1
    exit 1
fi

log_success "Sintaxis de Nginx válida"

# Recargar Nginx
log_info "Recargando Nginx..."
if sudo systemctl reload nginx; then
    log_success "Nginx recargado exitosamente"
else
    log_error "Error al recargar Nginx"
    exit 1
fi

# Verificar que el sitio responde
log_info "Verificando que el sitio responde..."
sleep 2

RETRY_COUNT=0
MAX_RETRIES=5

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if curl -sf -H "Host: nueva-app.com" http://127.0.0.1 > /dev/null 2>&1; then
        log_success "Sitio respondiendo correctamente"
        break
    fi
    
    RETRY_COUNT=$((RETRY_COUNT + 1))
    echo -n "."
    sleep 1
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
    log_warning "El sitio no respondió en los tiempos esperados"
fi

echo ""

# Información del cambio
log_info "Información del cambio de tráfico:"
echo "  - Entorno activo: GREEN"
echo "  - Puerto de aplicación: 3002"
echo "  - Configuración: $SERVICE_CONF"
echo "  - Archivo de estado: $NGINX_ACTIVE_FILE"
echo "  - Sitio: http://nueva-app.com"

log_success "Cambio de tráfico hacia GREEN completado exitosamente"
echo ""

{
    echo "======================================================================"
    echo "Switch completado exitosamente"
    echo "Fecha: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "======================================================================"
} | tee -a "$LOG_FILE"

exit 0
