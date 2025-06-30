#!/bin/bash

# Advanced CI/CD Pipeline Automation Script
# This script orchestrates comprehensive automated deployment processes
# with intelligent decision making and comprehensive error handling

set -euo pipefail

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
readonly LOG_DIR="${PROJECT_ROOT}/logs"
readonly CONFIG_FILE="${PROJECT_ROOT}/automation/config.yaml"

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "${LOG_DIR}/pipeline.log"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "${LOG_DIR}/pipeline.log"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "${LOG_DIR}/pipeline.log"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "${LOG_DIR}/pipeline.log"
}

# Initialize pipeline environment
init_pipeline() {
    log_info "Initializing CI/CD pipeline environment"
    
    # Create necessary directories
    mkdir -p "${LOG_DIR}" "${PROJECT_ROOT}/reports" "${PROJECT_ROOT}/artifacts"
    
    # Load environment variables
    if [[ -f "${PROJECT_ROOT}/.env" ]]; then
        set -a
        source "${PROJECT_ROOT}/.env"
        set +a
        log_info "Environment variables loaded from .env file"
    fi
    
    # Validate required tools
    local required_tools=("docker" "kubectl" "git" "python3" "npm" "terraform")
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            log_error "Required tool '$tool' is not installed or not in PATH"
            return 1
        fi
    done
    
    log_success "Pipeline environment initialized successfully"
}

# Advanced code quality analysis with multiple tools
analyze_code_quality() {
    log_info "Starting comprehensive code quality analysis"
    
    local quality_score=0
    local total_checks=0
    
    # ESLint for JavaScript/TypeScript
    if [[ -f "package.json" ]]; then
        log_info "Running ESLint analysis"
        if npm run lint -- --format json > "${LOG_DIR}/eslint-report.json" 2>&1; then
            ((quality_score++))
        else
            log_warning "ESLint found issues - check eslint-report.json"
        fi
        ((total_checks++))
    fi
    
    # Pylint for Python
    if find . -name "*.py" -type f | head -1 > /dev/null 2>&1; then
        log_info "Running Pylint analysis"
        if pylint src/ --output-format=json > "${LOG_DIR}/pylint-report.json" 2>&1; then
            ((quality_score++))
        else
            log_warning "Pylint found issues - check pylint-report.json"
        fi
        ((total_checks++))
    fi
    
    # SonarQube analysis
    if command -v sonar-scanner &> /dev/null; then
        log_info "Running SonarQube analysis"
        if sonar-scanner \
            -Dsonar.projectKey="${PROJECT_NAME:-obl-claude-code}" \
            -Dsonar.sources=. \
            -Dsonar.host.url="${SONAR_HOST_URL:-http://localhost:9000}" \
            -Dsonar.login="${SONAR_TOKEN:-}" > "${LOG_DIR}/sonar-report.log" 2>&1; then
            ((quality_score++))
        else
            log_warning "SonarQube analysis failed - check sonar-report.log"
        fi
        ((total_checks++))
    fi
    
    # Calculate quality percentage
    local quality_percentage=$((quality_score * 100 / total_checks))
    
    if [[ $quality_percentage -ge 80 ]]; then
        log_success "Code quality analysis passed with $quality_percentage% score"
        return 0
    else
        log_error "Code quality analysis failed with $quality_percentage% score (minimum 80% required)"
        return 1
    fi
}

# Comprehensive security scanning
perform_security_scan() {
    log_info "Initiating comprehensive security scan"
    
    local security_issues=0
    
    # SAST (Static Application Security Testing)
    if command -v bandit &> /dev/null; then
        log_info "Running Bandit security scan"
        if ! bandit -r . -f json -o "${LOG_DIR}/bandit-report.json" 2>&1; then
            ((security_issues++))
            log_warning "Bandit found security issues"
        fi
    fi
    
    # Dependency vulnerability scanning
    if [[ -f "package.json" ]]; then
        log_info "Running npm audit"
        if ! npm audit --audit-level moderate --json > "${LOG_DIR}/npm-audit.json" 2>&1; then
            ((security_issues++))
            log_warning "npm audit found vulnerabilities"
        fi
    fi
    
    if [[ -f "requirements.txt" ]]; then
        log_info "Running safety check"
        if command -v safety &> /dev/null; then
            if ! safety check --json --output "${LOG_DIR}/safety-report.json" 2>&1; then
                ((security_issues++))
                log_warning "Safety check found vulnerabilities"
            fi
        fi
    fi
    
    # Container image scanning (if Dockerfile exists)
    if [[ -f "Dockerfile" ]]; then
        log_info "Running container security scan with Trivy"
        if command -v trivy &> /dev/null; then
            if ! trivy image --format json --output "${LOG_DIR}/trivy-report.json" "${PROJECT_NAME:-app}:latest" 2>&1; then
                ((security_issues++))
                log_warning "Trivy found container vulnerabilities"
            fi
        fi
    fi
    
    if [[ $security_issues -eq 0 ]]; then
        log_success "Security scan completed successfully - no critical issues found"
        return 0
    else
        log_error "Security scan found $security_issues issue(s) - review required"
        return 1
    fi
}

# Intelligent test execution with parallel processing
execute_comprehensive_tests() {
    log_info "Executing comprehensive test suite"
    
    local test_results=()
    
    # Unit tests
    if [[ -f "pytest.ini" || -d "tests/" ]]; then
        log_info "Running unit tests with coverage"
        if pytest tests/unit/ \
            --cov=src/ \
            --cov-report=xml:"${LOG_DIR}/coverage.xml" \
            --cov-report=html:"${LOG_DIR}/coverage_html" \
            --junit-xml="${LOG_DIR}/junit.xml" \
            --tb=short; then
            test_results+=("unit:PASS")
            log_success "Unit tests passed"
        else
            test_results+=("unit:FAIL")
            log_error "Unit tests failed"
        fi
    fi
    
    # Integration tests
    if [[ -d "tests/integration/" ]]; then
        log_info "Running integration tests"
        if pytest tests/integration/ \
            --maxfail=5 \
            --junit-xml="${LOG_DIR}/integration-junit.xml"; then
            test_results+=("integration:PASS")
            log_success "Integration tests passed"
        else
            test_results+=("integration:FAIL")
            log_error "Integration tests failed"
        fi
    fi
    
    # End-to-end tests
    if [[ -d "tests/e2e/" ]]; then
        log_info "Running end-to-end tests"
        if pytest tests/e2e/ \
            --junit-xml="${LOG_DIR}/e2e-junit.xml"; then
            test_results+=("e2e:PASS")
            log_success "End-to-end tests passed"
        else
            test_results+=("e2e:FAIL")
            log_error "End-to-end tests failed"
        fi
    fi
    
    # Performance tests
    if [[ -d "tests/performance/" ]]; then
        log_info "Running performance tests"
        if locust --headless --users 100 --spawn-rate 10 --run-time 30s \
            --host="${TEST_HOST:-http://localhost:8000}" \
            --html="${LOG_DIR}/performance-report.html"; then
            test_results+=("performance:PASS")
            log_success "Performance tests passed"
        else
            test_results+=("performance:FAIL")
            log_error "Performance tests failed"
        fi
    fi
    
    # Evaluate overall test results
    local failed_tests=$(printf '%s\n' "${test_results[@]}" | grep -c "FAIL" || true)
    
    if [[ $failed_tests -eq 0 ]]; then
        log_success "All test suites passed successfully"
        return 0
    else
        log_error "$failed_tests test suite(s) failed"
        return 1
    fi
}

# Advanced artifact building with optimization
build_optimized_artifacts() {
    log_info "Building optimized artifacts"
    
    local build_start_time=$(date +%s)
    
    # Docker multi-stage build with optimization
    if [[ -f "Dockerfile" ]]; then
        log_info "Building Docker image with multi-stage optimization"
        
        docker build \
            --build-arg BUILD_DATE="$(date -u +'%Y-%m-%dT%H:%M:%SZ')" \
            --build-arg VCS_REF="$(git rev-parse --short HEAD)" \
            --build-arg VERSION="${VERSION:-latest}" \
            --target production \
            --compress \
            --pull \
            -t "${PROJECT_NAME:-app}:${VERSION:-latest}" \
            -t "${PROJECT_NAME:-app}:$(git rev-parse --short HEAD)" \
            . > "${LOG_DIR}/docker-build.log" 2>&1
        
        # Image security scanning
        if command -v docker-bench-security &> /dev/null; then
            log_info "Running Docker security benchmark"
            docker-bench-security > "${LOG_DIR}/docker-security.log" 2>&1 || log_warning "Docker security scan completed with warnings"
        fi
        
        # Image optimization
        if command -v dive &> /dev/null; then
            log_info "Analyzing image efficiency"
            dive "${PROJECT_NAME:-app}:${VERSION:-latest}" --ci > "${LOG_DIR}/dive-analysis.txt" 2>&1 || true
        fi
    fi
    
    # Frontend build optimization
    if [[ -f "package.json" ]] && grep -q "\"build\"" package.json; then
        log_info "Building optimized frontend assets"
        npm run build > "${LOG_DIR}/frontend-build.log" 2>&1
        
        # Bundle analysis
        if command -v webpack-bundle-analyzer &> /dev/null; then
            npx webpack-bundle-analyzer build/static/js/*.js --report --format json --out "${LOG_DIR}/bundle-analysis.json" || true
        fi
    fi
    
    local build_end_time=$(date +%s)
    local build_duration=$((build_end_time - build_start_time))
    
    log_success "Artifact building completed in ${build_duration} seconds"
    
    # Store build metadata
    cat > "${LOG_DIR}/build-metadata.json" << EOF
{
    "timestamp": "$(date -u +'%Y-%m-%dT%H:%M:%SZ')",
    "duration": ${build_duration},
    "commit": "$(git rev-parse HEAD)",
    "branch": "$(git rev-parse --abbrev-ref HEAD)",
    "version": "${VERSION:-latest}"
}
EOF
}

# Intelligent deployment with rollback capabilities
deploy_with_intelligence() {
    local environment=$1
    local deployment_strategy=${2:-"rolling"}
    
    log_info "Deploying to $environment using $deployment_strategy strategy"
    
    # Pre-deployment validation
    if ! validate_deployment_environment "$environment"; then
        log_error "Deployment environment validation failed"
        return 1
    fi
    
    # Execute deployment based on strategy
    case $deployment_strategy in
        "blue-green")
            deploy_blue_green "$environment"
            ;;
        "canary")
            deploy_canary "$environment"
            ;;
        "rolling")
            deploy_rolling "$environment"
            ;;
        *)
            log_error "Unknown deployment strategy: $deployment_strategy"
            return 1
            ;;
    esac
    
    # Post-deployment verification
    if verify_deployment "$environment"; then
        log_success "Deployment to $environment completed successfully"
        return 0
    else
        log_error "Deployment verification failed - initiating rollback"
        rollback_deployment "$environment"
        return 1
    fi
}

# Main pipeline orchestration
main() {
    local operation=${1:-"full"}
    
    log_info "Starting CI/CD pipeline - Operation: $operation"
    
    # Initialize pipeline environment
    if ! init_pipeline; then
        log_error "Pipeline initialization failed"
        exit 1
    fi
    
    case $operation in
        "full")
            analyze_code_quality && \
            perform_security_scan && \
            execute_comprehensive_tests && \
            build_optimized_artifacts && \
            deploy_with_intelligence "staging" "rolling"
            ;;
        "test")
            execute_comprehensive_tests
            ;;
        "build")
            build_optimized_artifacts
            ;;
        "deploy")
            deploy_with_intelligence "${2:-staging}" "${3:-rolling}"
            ;;
        *)
            log_error "Unknown operation: $operation"
            echo "Usage: $0 [full|test|build|deploy] [environment] [strategy]"
            exit 1
            ;;
    esac
    
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        log_success "Pipeline operation '$operation' completed successfully"
    else
        log_error "Pipeline operation '$operation' failed with exit code $exit_code"
    fi
    
    exit $exit_code
}

# Execute main function with all arguments
main "$@"