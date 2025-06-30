#!/bin/bash

# Obl Claude Code - Advanced Setup Script
# This script initializes the comprehensive automation environment

set -euo pipefail

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
readonly PYTHON_VERSION="3.11"
readonly NODE_VERSION="18"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

log() {
    echo -e "${BLUE}[SETUP]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Install system dependencies
install_system_dependencies() {
    log "Installing system dependencies..."
    
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Linux
        if command_exists apt-get; then
            sudo apt-get update
            sudo apt-get install -y \
                curl \
                wget \
                git \
                build-essential \
                python3 \
                python3-pip \
                python3-venv \
                nodejs \
                npm \
                docker.io \
                docker-compose \
                jq \
                yq
        elif command_exists yum; then
            sudo yum update -y
            sudo yum install -y \
                curl \
                wget \
                git \
                gcc \
                gcc-c++ \
                python3 \
                python3-pip \
                nodejs \
                npm \
                docker \
                docker-compose \
                jq
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        if ! command_exists brew; then
            log "Installing Homebrew..."
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        fi
        
        brew update
        brew install \
            curl \
            wget \
            git \
            python@${PYTHON_VERSION} \
            node@${NODE_VERSION} \
            docker \
            docker-compose \
            jq \
            yq
    fi
    
    success "System dependencies installed"
}

# Install Python tools and dependencies
setup_python_environment() {
    log "Setting up Python environment..."
    
    # Create virtual environment
    python3 -m venv venv
    source venv/bin/activate
    
    # Upgrade pip
    pip install --upgrade pip setuptools wheel
    
    # Install core automation dependencies
    cat > requirements.txt << EOF
# Core automation framework
asyncio-mqtt>=0.11.1
pyyaml>=6.0
click>=8.1.3
rich>=13.3.5
httpx>=0.24.1
aiofiles>=23.1.0

# Process orchestration
celery>=5.2.7
redis>=4.5.5
kubernetes>=26.1.0

# Monitoring and observability
prometheus-client>=0.16.0
structlog>=23.1.0
sentry-sdk>=1.25.1

# Security and compliance
bandit>=1.7.5
safety>=2.3.5
semgrep>=1.25.0

# Testing frameworks
pytest>=7.3.1
pytest-asyncio>=0.21.0
pytest-cov>=4.1.0
pytest-xdist>=3.3.1
locust>=2.15.1

# Quality assurance
black>=23.3.0
isort>=5.12.0
flake8>=6.0.0
mypy>=1.3.0
pylint>=2.17.4

# Infrastructure tools
terraform-compliance>=1.3.40
checkov>=2.3.227
ansible>=7.5.0

# Development tools
pre-commit>=3.3.2
jupyterlab>=4.0.1
ipdb>=0.13.13
EOF

    pip install -r requirements.txt
    
    # Install additional security tools
    pip install \
        truffleHog \
        detect-secrets \
        pip-audit
    
    success "Python environment configured"
}

# Setup Node.js environment
setup_nodejs_environment() {
    log "Setting up Node.js environment..."
    
    # Install global npm packages for automation
    npm install -g \
        eslint \
        prettier \
        @typescript-eslint/parser \
        @typescript-eslint/eslint-plugin \
        jshint \
        npm-audit \
        snyk \
        lighthouse \
        @commitlint/cli \
        @commitlint/config-conventional
    
    # Create package.json for project
    cat > package.json << EOF
{
  "name": "obl-claude-code-automation",
  "version": "1.0.0",
  "description": "Advanced automation framework with comprehensive process orchestration",
  "main": "index.js",
  "scripts": {
    "test": "jest",
    "lint": "eslint . --ext .js,.ts,.jsx,.tsx",
    "lint:fix": "eslint . --ext .js,.ts,.jsx,.tsx --fix",
    "format": "prettier --write .",
    "audit": "npm audit --audit-level moderate",
    "security-check": "snyk test",
    "build": "webpack --mode production",
    "dev": "webpack-dev-server --mode development"
  },
  "keywords": ["automation", "ci-cd", "orchestration", "monitoring"],
  "author": "Obl Claude Code",
  "license": "MIT",
  "devDependencies": {
    "@types/jest": "^29.5.1",
    "@types/node": "^20.2.5",
    "jest": "^29.5.0",
    "typescript": "^5.0.4",
    "webpack": "^5.84.1",
    "webpack-cli": "^5.1.1",
    "webpack-dev-server": "^4.15.0"
  },
  "dependencies": {
    "axios": "^1.4.0",
    "dotenv": "^16.1.4",
    "express": "^4.18.2",
    "ws": "^8.13.0"
  }
}
EOF
    
    npm install
    
    success "Node.js environment configured"
}

# Install and configure Docker
setup_docker() {
    log "Setting up Docker environment..."
    
    # Start Docker service
    if systemctl is-active --quiet docker; then
        log "Docker is already running"
    else
        sudo systemctl start docker
        sudo systemctl enable docker
    fi
    
    # Add current user to docker group (Linux only)
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        sudo usermod -aG docker "$USER"
        warning "Please log out and log back in for Docker group changes to take effect"
    fi
    
    # Create docker-compose.yml for development environment
    cat > docker-compose.yml << EOF
version: '3.8'

services:
  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    command: redis-server --appendonly yes
    volumes:
      - redis_data:/data
    networks:
      - automation_network

  postgresql:
    image: postgres:15-alpine
    environment:
      POSTGRES_DB: automation
      POSTGRES_USER: automation_user
      POSTGRES_PASSWORD: automation_pass
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks:
      - automation_network

  prometheus:
    image: prom/prometheus:latest
    ports:
      - "9090:9090"
    volumes:
      - ./monitoring/prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/etc/prometheus/console_libraries'
      - '--web.console.templates=/etc/prometheus/consoles'
    networks:
      - automation_network

  grafana:
    image: grafana/grafana:latest
    ports:
      - "3000:3000"
    environment:
      GF_SECURITY_ADMIN_PASSWORD: admin
    volumes:
      - grafana_data:/var/lib/grafana
    networks:
      - automation_network

volumes:
  redis_data:
  postgres_data:
  prometheus_data:
  grafana_data:

networks:
  automation_network:
    driver: bridge
EOF

    success "Docker environment configured"
}

# Install Kubernetes tools
setup_kubernetes_tools() {
    log "Installing Kubernetes tools..."
    
    # Install kubectl
    if ! command_exists kubectl; then
        if [[ "$OSTYPE" == "linux-gnu"* ]]; then
            curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
            sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
        elif [[ "$OSTYPE" == "darwin"* ]]; then
            brew install kubectl
        fi
    fi
    
    # Install Helm
    if ! command_exists helm; then
        curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    fi
    
    # Install k9s (Kubernetes CLI management tool)
    if ! command_exists k9s; then
        if [[ "$OSTYPE" == "linux-gnu"* ]]; then
            curl -sL https://github.com/derailed/k9s/releases/latest/download/k9s_Linux_amd64.tar.gz | tar xfz - -C /tmp
            sudo mv /tmp/k9s /usr/local/bin/
        elif [[ "$OSTYPE" == "darwin"* ]]; then
            brew install k9s
        fi
    fi
    
    success "Kubernetes tools installed"
}

# Install security and compliance tools
setup_security_tools() {
    log "Installing security and compliance tools..."
    
    # Install trivy (container scanner)
    if ! command_exists trivy; then
        if [[ "$OSTYPE" == "linux-gnu"* ]]; then
            sudo apt-get update
            sudo apt-get install wget apt-transport-https gnupg lsb-release
            wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo apt-key add -
            echo "deb https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" | sudo tee -a /etc/apt/sources.list.d/trivy.list
            sudo apt-get update
            sudo apt-get install trivy
        elif [[ "$OSTYPE" == "darwin"* ]]; then
            brew install trivy
        fi
    fi
    
    # Install hadolint (Dockerfile linter)
    if ! command_exists hadolint; then
        if [[ "$OSTYPE" == "linux-gnu"* ]]; then
            wget -O /tmp/hadolint https://github.com/hadolint/hadolint/releases/latest/download/hadolint-Linux-x86_64
            chmod +x /tmp/hadolint
            sudo mv /tmp/hadolint /usr/local/bin/
        elif [[ "$OSTYPE" == "darwin"* ]]; then
            brew install hadolint
        fi
    fi
    
    success "Security tools installed"
}

# Setup project directories and configuration
setup_project_structure() {
    log "Setting up project structure..."
    
    # Create necessary directories
    mkdir -p \
        logs \
        reports \
        artifacts \
        monitoring \
        k8s \
        terraform \
        scripts \
        tests/{unit,integration,e2e,performance} \
        examples
    
    # Create .env template
    cat > .env.template << EOF
# Environment Configuration
ENVIRONMENT=development

# Database Configuration
DATABASE_URL=postgresql://automation_user:automation_pass@localhost:5432/automation

# Redis Configuration
REDIS_URL=redis://localhost:6379

# API Configuration
API_HOST=localhost
API_PORT=8000

# Monitoring Configuration
PROMETHEUS_URL=http://localhost:9090
GRAFANA_URL=http://localhost:3000

# Notification Configuration
SLACK_WEBHOOK_URL=https://hooks.slack.com/services/YOUR/WEBHOOK/URL
EMAIL_SMTP_SERVER=smtp.gmail.com
EMAIL_SMTP_PORT=587
EMAIL_USERNAME=your-email@example.com
EMAIL_PASSWORD=your-app-password

# Security Configuration
SECRET_KEY=your-secret-key-here
JWT_SECRET=your-jwt-secret-here

# AWS Configuration (if using AWS services)
AWS_ACCESS_KEY_ID=your-access-key
AWS_SECRET_ACCESS_KEY=your-secret-key
AWS_REGION=us-west-2

# Docker Registry Configuration
DOCKER_REGISTRY=registry.example.com
DOCKER_USERNAME=your-username
DOCKER_PASSWORD=your-password
EOF

    # Create .gitignore
    cat > .gitignore << EOF
# Python
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
build/
develop-eggs/
dist/
downloads/
eggs/
.eggs/
lib/
lib64/
parts/
sdist/
var/
wheels/
pip-wheel-metadata/
share/python-wheels/
*.egg-info/
.installed.cfg
*.egg
MANIFEST

# Virtual Environment
venv/
env/
ENV/

# Node.js
node_modules/
npm-debug.log*
yarn-debug.log*
yarn-error.log*

# Logs
logs/
*.log

# Reports
reports/
artifacts/

# Environment variables
.env

# IDE
.vscode/
.idea/
*.swp
*.swo

# OS
.DS_Store
Thumbs.db

# Docker
.docker/

# Terraform
*.tfstate
*.tfstate.*
.terraform/
.terraform.lock.hcl

# Kubernetes
*.kubeconfig

# Security
secrets/
*.pem
*.key
*.crt
EOF

    # Create pre-commit configuration
    cat > .pre-commit-config.yaml << EOF
repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.4.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-yaml
      - id: check-added-large-files
      - id: check-merge-conflict

  - repo: https://github.com/psf/black
    rev: 23.3.0
    hooks:
      - id: black

  - repo: https://github.com/pycqa/isort
    rev: 5.12.0
    hooks:
      - id: isort

  - repo: https://github.com/pycqa/flake8
    rev: 6.0.0
    hooks:
      - id: flake8

  - repo: https://github.com/PyCQA/bandit
    rev: 1.7.5
    hooks:
      - id: bandit
        args: ["-r", "src/"]

  - repo: https://github.com/Yelp/detect-secrets
    rev: v1.4.0
    hooks:
      - id: detect-secrets
        args: ['--baseline', '.secrets.baseline']
EOF

    # Initialize pre-commit
    if command_exists pre-commit; then
        pre-commit install
    fi
    
    success "Project structure created"
}

# Setup monitoring configuration
setup_monitoring() {
    log "Setting up monitoring configuration..."
    
    # Create Prometheus configuration
    mkdir -p monitoring
    cat > monitoring/prometheus.yml << EOF
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  - "alerting-rules.yml"

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'automation-metrics'
    static_configs:
      - targets: ['localhost:8000']
    metrics_path: '/metrics'
    scrape_interval: 10s

  - job_name: 'node-exporter'
    static_configs:
      - targets: ['localhost:9100']

alerting:
  alertmanagers:
    - static_configs:
        - targets:
          - alertmanager:9093
EOF

    success "Monitoring configuration created"
}

# Verify installation
verify_installation() {
    log "Verifying installation..."
    
    local verification_passed=true
    
    # Check Python
    if python3 --version >/dev/null 2>&1; then
        success "Python: $(python3 --version)"
    else
        error "Python installation failed"
        verification_passed=false
    fi
    
    # Check Node.js
    if node --version >/dev/null 2>&1; then
        success "Node.js: $(node --version)"
    else
        error "Node.js installation failed"
        verification_passed=false
    fi
    
    # Check Docker
    if docker --version >/dev/null 2>&1; then
        success "Docker: $(docker --version)"
    else
        error "Docker installation failed"
        verification_passed=false
    fi
    
    # Check kubectl
    if kubectl version --client >/dev/null 2>&1; then
        success "kubectl: $(kubectl version --client --short)"
    else
        warning "kubectl not installed (optional)"
    fi
    
    if $verification_passed; then
        success "All core components installed successfully!"
    else
        error "Some installations failed. Please check the logs above."
        exit 1
    fi
}

# Main setup function
main() {
    log "Starting Obl Claude Code automation framework setup..."
    
    install_system_dependencies
    setup_python_environment
    setup_nodejs_environment
    setup_docker
    setup_kubernetes_tools
    setup_security_tools
    setup_project_structure
    setup_monitoring
    verify_installation
    
    success "Setup completed successfully!"
    echo
    echo "Next steps:"
    echo "1. Copy .env.template to .env and update with your configurations"
    echo "2. Start the development environment: docker-compose up -d"
    echo "3. Run the automation framework: ./scripts/run-automation.sh"
    echo "4. View monitoring dashboards at http://localhost:3000 (Grafana)"
    echo "5. Check metrics at http://localhost:9090 (Prometheus)"
}

# Execute main function
main "$@"