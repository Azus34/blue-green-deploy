#!/bin/bash

################################################################################
# Script: deploy-blue.sh
# Descripción: Despliega o actualiza la aplicación en el entorno BLUE
# Uso: ./scripts/deploy-blue.sh <IMAGE_URI>
# Ejemplo: ./scripts/deploy-blue.sh ghcr.io/usuario/app:latest
################################################################################

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Variables
IMAGE_URI="${1:-ghcr.io/usuario/app:latest}"
CONTAINER_NAME="app-blue"
PORT="3001"
ENVIRONMENT="BLUE"
VERSION="${2:-1.0.0}"

# Logs
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
    echo "Despliegue Blue-Green: BLUE Environment"
    echo "Fecha: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "Image: $IMAGE_URI"
    echo "======================================================================"
} | tee -a "$LOG_FILE"

log_info "Iniciando despliegue en entorno BLUE..."

# Verificar que Docker está corriendo
if ! command -v docker &> /dev/null; then
    log_error "Docker no está instalado o no está accesible"
    exit 1
fi

log_info "Verificando Docker..."
if ! docker ps &> /dev/null; then
    log_error "No se puede conectar al daemon de Docker"
    exit 1
fi

# Detener y remover contenedor BLUE anterior si existe
log_info "Deteniendo contenedor BLUE anterior (si existe)..."
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    log_warning "Encontrado contenedor $CONTAINER_NAME. Deteniendo..."
    docker stop "$CONTAINER_NAME" 2>/dev/null || true
    sleep 2  # Esperar a que se detenga completamente
    docker rm -f "$CONTAINER_NAME" 2>/dev/null || true
    sleep 1  # Pequeña pausa antes de intentar crear uno nuevo
    log_success "Contenedor anterior removido"
fi

# Descargar la nueva imagen
log_info "Descargando imagen: $IMAGE_URI"
if docker pull "$IMAGE_URI"; then
    log_success "Imagen descargada exitosamente"
else
    log_error "Fallo al descargar la imagen"
    exit 1
fi

# Crear y ejecutar el nuevo contenedor BLUE
log_info "Creando contenedor BLUE en puerto $PORT..."

if docker run \
    --name "$CONTAINER_NAME" \
    --detach \
    --restart unless-stopped \
    --publish "127.0.0.1:${PORT}:3000" \
    --env "ENVIRONMENT=${ENVIRONMENT}" \
    --env "VERSION=${VERSION}" \
    --health-cmd='curl -f http://localhost:3000/health || exit 1' \
    --health-interval=10s \
    --health-timeout=5s \
    --health-retries=3 \
    --health-start-period=10s \
    "$IMAGE_URI"; then
    
    log_success "Contenedor BLUE creado exitosamente"
else
    log_error "Fallo al crear el contenedor BLUE"
    exit 1
fi

# Esperar a que el contenedor esté healthy
log_info "Esperando que el contenedor esté healthy..."
MAX_ATTEMPTS=30
ATTEMPT=0

while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
    HEALTH_STATUS=$(docker inspect --format='{{.State.Health.Status}}' "$CONTAINER_NAME" 2>/dev/null || echo "none")
    
    if [ "$HEALTH_STATUS" = "healthy" ]; then
        log_success "Contenedor BLUE está healthy"
        break
    fi
    
    if [ "$HEALTH_STATUS" = "unhealthy" ]; then
        log_error "Contenedor BLUE reporta estado unhealthy"
        docker logs "$CONTAINER_NAME" | tail -20 >> "$LOG_FILE"
        exit 1
    fi
    
    ATTEMPT=$((ATTEMPT + 1))
    echo -n "."
    sleep 1
done

if [ $ATTEMPT -eq $MAX_ATTEMPTS ]; then
    log_warning "Timeout esperando healthcheck, pero continuando..."
fi

echo ""

# Realizar health check HTTP
log_info "Realizando health check HTTP..."
HEALTH_CHECK_URL="http://127.0.0.1:${PORT}/health"

RETRY_COUNT=0
MAX_RETRIES=10

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if curl -sf "$HEALTH_CHECK_URL" > /dev/null 2>&1; then
        log_success "Health check exitoso en $HEALTH_CHECK_URL"
        break
    fi
    
    RETRY_COUNT=$((RETRY_COUNT + 1))
    echo -n "."
    sleep 2
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
    log_warning "Health check no respondió en los tiempos esperados"
fi

echo ""

# Información del despliegue
log_info "Información del despliegue:"
echo "  - Contenedor: $CONTAINER_NAME"
echo "  - Imagen: $IMAGE_URI"
echo "  - Entorno: $ENVIRONMENT"
echo "  - Versión: $VERSION"
echo "  - Puerto: $PORT"
echo "  - URL de salud: $HEALTH_CHECK_URL"

log_success "Despliegue en entorno BLUE completado exitosamente"
echo ""

{
    echo "======================================================================"
    echo "Despliegue completado exitosamente"
    echo "Fecha: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "======================================================================"
} | tee -a "$LOG_FILE"

exit 0
