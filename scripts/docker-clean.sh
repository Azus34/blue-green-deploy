#!/bin/bash

################################################################################
# Script: docker-clean.sh
# Descripción: Limpia contenedores e imágenes antiguas de Docker
# Uso: ./scripts/docker-clean.sh
################################################################################

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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
    echo "Docker Cleanup: Limpieza de recursos"
    echo "Fecha: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "======================================================================"
} | tee -a "$LOG_FILE"

log_info "Iniciando limpieza de Docker..."

# Verificar que Docker está disponible
if ! command -v docker &> /dev/null; then
    log_error "Docker no está instalado o no está accesible"
    exit 1
fi

# Mostrar estado actual
log_info "Estado actual de Docker:"
echo "  Contenedores: $(docker ps -a -q | wc -l)"
echo "  Imágenes: $(docker images -q | wc -l)"

# Detener contenedores detenidos (si alguno está dañado)
log_info "Buscando contenedores en estado Exited..."
EXITED_CONTAINERS=$(docker ps -a -q -f status=exited | wc -l)

if [ "$EXITED_CONTAINERS" -gt 0 ]; then
    log_warning "Encontrados $EXITED_CONTAINERS contenedores detenidos"
    log_info "Removiendo contenedores detenidos..."
    docker container prune -f --filter "until=24h"
    log_success "Contenedores detenidos removidos"
else
    log_info "No hay contenedores detenidos para limpiar"
fi

# Remover imágenes no utilizadas
log_info "Buscando imágenes no utilizadas..."
DANGLING_IMAGES=$(docker images -q -f dangling=true | wc -l)

if [ "$DANGLING_IMAGES" -gt 0 ]; then
    log_warning "Encontradas $DANGLING_IMAGES imágenes sin etiqueta (dangling)"
    log_info "Removiendo imágenes sin etiqueta..."
    docker image prune -f
    log_success "Imágenes sin etiqueta removidas"
else
    log_info "No hay imágenes sin etiqueta para limpiar"
fi

# Limpiar volúmenes no utilizados
log_info "Buscando volúmenes no utilizados..."
UNUSED_VOLUMES=$(docker volume ls -q -f dangling=true | wc -l)

if [ "$UNUSED_VOLUMES" -gt 0 ]; then
    log_warning "Encontrados $UNUSED_VOLUMES volúmenes no utilizados"
    log_info "Removiendo volúmenes no utilizados..."
    docker volume prune -f
    log_success "Volúmenes no utilizados removidos"
else
    log_info "No hay volúmenes no utilizados para limpiar"
fi

# Limpiar redes no utilizadas
log_info "Buscando redes no utilizadas..."
UNUSED_NETWORKS=$(docker network ls -q -f type=custom | xargs -I {} sh -c 'docker network inspect {} -f "{{.Containers}}" | grep -q "map\[\]" && echo {}' | wc -l)

if [ "$UNUSED_NETWORKS" -gt 0 ]; then
    log_warning "Encontradas $UNUSED_NETWORKS redes no utilizadas"
    log_info "Removiendo redes no utilizadas..."
    docker network prune -f
    log_success "Redes no utilizadas removidas"
else
    log_info "No hay redes no utilizadas para limpiar"
fi

# Mostrar estado final
log_info "Estado final de Docker:"
echo "  Contenedores: $(docker ps -a -q | wc -l)"
echo "  Imágenes: $(docker images -q | wc -l)"

# Información sobre espacio en disco
log_info "Espacio utilizado por Docker:"
docker system df

log_success "Limpieza de Docker completada exitosamente"
echo ""

{
    echo "======================================================================"
    echo "Limpieza completada exitosamente"
    echo "Fecha: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "======================================================================"
} | tee -a "$LOG_FILE"

exit 0
