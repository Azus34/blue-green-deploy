#!/bin/bash

################################################################################
# Script: setup-vps.sh
# Descripción: Configura el VPS para Blue-Green Deployment
# Uso: sudo ./scripts/setup-vps.sh
# Nota: Ejecutar una sola vez para preparar el servidor
################################################################################

set -e

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Funciones
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Verificar que somos root
if [ "$EUID" -ne 0 ]; then
    log_error "Este script debe ejecutarse con sudo"
    exit 1
fi

log_info "======================================================================"
log_info "Setup VPS para Blue-Green Deployment"
log_info "======================================================================"

# Actualizar sistema
log_info "Actualizando sistema..."
apt-get update -qq
apt-get upgrade -y -qq
log_success "Sistema actualizado"

# Instalar dependencias
log_info "Instalando dependencias..."
apt-get install -y -qq \
    curl \
    wget \
    git \
    build-essential \
    net-tools \
    htop \
    vim \
    nano

log_success "Dependencias instaladas"

# Verificar Docker
log_info "Verificando Docker..."
if ! command -v docker &> /dev/null; then
    log_warning "Docker no encontrado. Instalando..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    rm get-docker.sh
    log_success "Docker instalado"
    
    # Agregar usuario al grupo docker
    if id "$SUDO_USER" &>/dev/null; then
        usermod -aG docker "$SUDO_USER"
        log_info "Usuario $SUDO_USER agregado al grupo docker"
    fi
else
    log_success "Docker ya está instalado"
    docker --version
fi

# Verificar Docker Compose
log_info "Verificando Docker Compose..."
if ! command -v docker-compose &> /dev/null; then
    log_warning "Docker Compose no encontrado. Instalando..."
    curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    log_success "Docker Compose instalado"
else
    log_success "Docker Compose ya está instalado"
    docker-compose --version
fi

# Crear directorios necesarios
log_info "Creando directorios..."
mkdir -p /etc/nginx/conf.d
mkdir -p /etc/nginx/sites-available
mkdir -p /etc/nginx/sites-enabled
mkdir -p /var/log/nginx
mkdir -p /var/lib/docker/volumes
log_success "Directorios creados"

# Crear archivos de configuración de Nginx si no existen
log_info "Configurando Nginx..."

if [ ! -f "/etc/nginx/conf.d/blue.conf" ]; then
    log_warning "blue.conf no encontrado. Cópialo desde el repositorio."
fi

if [ ! -f "/etc/nginx/conf.d/green.conf" ]; then
    log_warning "green.conf no encontrado. Cópialo desde el repositorio."
fi

if [ ! -f "/etc/nginx/conf.d/service.conf" ]; then
    log_info "Creando service.conf inicial (apuntando a BLUE)..."
    cp /etc/nginx/conf.d/blue.conf /etc/nginx/conf.d/service.conf 2>/dev/null || \
    log_warning "No se pudo crear service.conf. Cópialo después."
fi

# Crear archivo de estado
log_info "Creando archivo de estado..."
echo "blue" > /etc/nginx/blue-green-active
chmod 644 /etc/nginx/blue-green-active
log_success "Archivo de estado creado"

# Crear directorio de logs
log_info "Configurando logs..."
touch /var/log/blue-green-deploy.log
chmod 644 /var/log/blue-green-deploy.log
log_success "Archivo de logs creado"

# Configurar Nginx
log_info "Verificando Nginx..."
if ! command -v nginx &> /dev/null; then
    log_warning "Nginx no está instalado en el sistema"
else
    log_success "Nginx está instalado"
    
    # Verificar sintaxis
    if nginx -t 2>/dev/null; then
        log_success "Sintaxis de Nginx válida"
    else
        log_warning "Verificar la configuración de Nginx"
    fi
fi

# Crear script wrapper para facilitar la ejecución sin password
log_info "Configurando sudoers para scripts..."
SUDOERS_ENTRY="$SUDO_USER ALL=(ALL) NOPASSWD: /usr/local/bin/switch-to-blue.sh, /usr/local/bin/switch-to-green.sh, /usr/sbin/systemctl reload nginx"

if ! grep -q "switch-to-blue" /etc/sudoers; then
    echo "$SUDOERS_ENTRY" | tee -a /etc/sudoers.d/blue-green-deploy > /dev/null
    chmod 440 /etc/sudoers.d/blue-green-deploy
    log_success "Sudoers configurado"
else
    log_info "Sudoers ya estaba configurado"
fi

# Crear enlace simbólico para los scripts (opcional)
log_info "Creando enlaces simbólicos para scripts..."
if [ -f "./scripts/deploy-blue.sh" ]; then
    chmod +x ./scripts/deploy-blue.sh
    chmod +x ./scripts/deploy-green.sh
    chmod +x ./scripts/switch-to-blue.sh
    chmod +x ./scripts/switch-to-green.sh
    chmod +x ./scripts/docker-clean.sh
    
    ln -sf "$(pwd)/scripts/deploy-blue.sh" /usr/local/bin/deploy-blue.sh 2>/dev/null || true
    ln -sf "$(pwd)/scripts/deploy-green.sh" /usr/local/bin/deploy-green.sh 2>/dev/null || true
    ln -sf "$(pwd)/scripts/switch-to-blue.sh" /usr/local/bin/switch-to-blue.sh 2>/dev/null || true
    ln -sf "$(pwd)/scripts/switch-to-green.sh" /usr/local/bin/switch-to-green.sh 2>/dev/null || true
    ln -sf "$(pwd)/scripts/docker-clean.sh" /usr/local/bin/docker-clean.sh 2>/dev/null || true
    
    log_success "Enlaces simbólicos creados"
fi

# Información final
log_success "======================================================================"
log_success "Setup completado exitosamente"
log_success "======================================================================"
echo ""
log_info "Próximos pasos:"
echo "  1. Copiar archivos de configuración de Nginx:"
echo "     - cp nginx/blue.conf /etc/nginx/conf.d/"
echo "     - cp nginx/green.conf /etc/nginx/conf.d/"
echo ""
echo "  2. Verificar la configuración:"
echo "     - sudo nginx -t"
echo ""
echo "  3. Ejecutar el primer despliegue:"
echo "     - sudo ./scripts/deploy-blue.sh ghcr.io/tu-usuario/tu-imagen:latest"
echo ""
echo "  4. Cambiar tráfico a BLUE:"
echo "     - sudo ./scripts/switch-to-blue.sh"
echo ""
echo "  5. Verificar que el sitio responde:"
echo "     - curl -H 'Host: nueva-app.com' http://127.0.0.1"
echo ""

exit 0
