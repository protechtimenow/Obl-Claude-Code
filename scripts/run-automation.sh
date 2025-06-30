#!/bin/bash

# Obl Claude Code - Automation Execution Script
# Intelligent automation runner with dynamic process selection and monitoring

set -euo pipefail

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
readonly CONFIG_FILE="${PROJECT_ROOT}/automation/config.yaml"
readonly LOG_DIR="${PROJECT_ROOT}/logs"
readonly REPORTS_DIR="${PROJECT_ROOT}/reports"

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly NC='\033[0m'

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "${LOG_DIR}/automation-runner.log"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "${LOG_DIR}/automation-runner.log"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "${LOG_DIR}/automation-runner.log"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "${LOG_DIR}/automation-runner.log"
}

log_header() {
    echo -e "${PURPLE}[AUTOMATION]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "${LOG_DIR}/automation-runner.log"
}

# Initialize environment
init_environment() {
    log_info "Initializing automation environment"
    
    # Create necessary directories
    mkdir -p "$LOG_DIR" "$REPORTS_DIR" "${PROJECT_ROOT}/artifacts"
    
    # Load environment variables
    if [[ -f "${PROJECT_ROOT}/.env" ]]; then
        set -a
        source "${PROJECT_ROOT}/.env"
        set +a
        log_info "Environment variables loaded"
    else
        log_warning "No .env file found - using defaults"
    fi
    
    # Activate Python virtual environment if it exists
    if [[ -f "${PROJECT_ROOT}/venv/bin/activate" ]]; then
        source "${PROJECT_ROOT}/venv/bin/activate"
        log_info "Python virtual environment activated"
    fi
    
    log_success "Environment initialized successfully"
}

# Display available processes
show_available_processes() {
    log_header "Available Automation Processes"
    echo
    
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_error "Configuration file not found: $CONFIG_FILE"
        return 1
    fi
    
    # Extract process names and descriptions using Python
    python3 << EOF
import yaml
import sys

try:
    with open('$CONFIG_FILE', 'r') as f:
        config = yaml.safe_load(f)
    
    processes = config.get('processes', {})
    if not processes:
        print("No processes defined in configuration")
        sys.exit(1)
    
    print("Available processes:")
    print("=" * 50)
    
    for name, details in processes.items():
        description = details.get('description', 'No description available')
        print(f"• {name}")
        print(f"  Description: {description}")
        
        if 'schedule' in details:
            print(f"  Schedule: {details['schedule']}")
        
        steps = details.get('steps', [])
        print(f"  Steps: {len(steps)} configured")
        print()
        
except Exception as e:
    print(f"Error reading configuration: {e}")
    sys.exit(1)
EOF
}

# Validate process configuration
validate_process() {
    local process_name=$1
    
    log_info "Validating process configuration: $process_name"
    
    # Use Python to validate the specific process
    python3 << EOF
import yaml
import sys

try:
    with open('$CONFIG_FILE', 'r') as f:
        config = yaml.safe_load(f)
    
    processes = config.get('processes', {})
    if '$process_name' not in processes:
        print(f"Process '{process_name}' not found in configuration")
        sys.exit(1)
    
    process = processes['$process_name']
    
    # Validate required fields
    if 'steps' not in process or not process['steps']:
        print(f"Process '{process_name}' has no steps defined")
        sys.exit(1)
    
    # Validate each step
    for i, step in enumerate(process['steps']):
        required_fields = ['name', 'command']
        for field in required_fields:
            if field not in step:
                print(f"Step {i+1} missing required field: {field}")
                sys.exit(1)
    
    print(f"Process '{process_name}' validation successful")
    
except Exception as e:
    print(f"Validation error: {e}")
    sys.exit(1)
EOF
    
    local validation_result=$?
    if [[ $validation_result -eq 0 ]]; then
        log_success "Process validation passed"
        return 0
    else
        log_error "Process validation failed"
        return 1
    fi
}

# Execute process using the orchestrator
execute_process() {
    local process_name=$1
    local environment=${2:-"development"}
    
    log_header "Executing Process: $process_name (Environment: $environment)"
    
    # Validate process first
    if ! validate_process "$process_name"; then
        return 1
    fi
    
    # Create execution timestamp
    local execution_id="$(date '+%Y%m%d_%H%M%S')_$$"
    local execution_log="${LOG_DIR}/execution_${process_name}_${execution_id}.log"
    
    log_info "Execution ID: $execution_id"
    log_info "Detailed logs: $execution_log"
    
    # Execute using the process orchestrator
    local start_time=$(date +%s)
    
    if python3 "${PROJECT_ROOT}/automation/process-orchestrator.py" \
        --config "$CONFIG_FILE" \
        --process "$process_name" \
        --environment "$environment" \
        --execution-id "$execution_id" 2>&1 | tee "$execution_log"; then
        
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        
        log_success "Process '$process_name' completed successfully in ${duration}s"
        
        # Generate execution summary
        generate_execution_summary "$process_name" "$execution_id" "$duration" "success"
        
        return 0
    else
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        
        log_error "Process '$process_name' failed after ${duration}s"
        
        # Generate execution summary
        generate_execution_summary "$process_name" "$execution_id" "$duration" "failure"
        
        return 1
    fi
}

# Generate execution summary
generate_execution_summary() {
    local process_name=$1
    local execution_id=$2
    local duration=$3
    local status=$4
    
    local summary_file="${REPORTS_DIR}/execution_summary_${execution_id}.json"
    
    cat > "$summary_file" << EOF
{
  "execution_id": "$execution_id",
  "process_name": "$process_name",
  "timestamp": "$(date -u +'%Y-%m-%dT%H:%M:%SZ')",
  "duration_seconds": $duration,
  "status": "$status",
  "environment": "${ENVIRONMENT:-development}",
  "logs": {
    "main": "logs/automation-runner.log",
    "detailed": "logs/execution_${process_name}_${execution_id}.log"
  },
  "reports": {
    "summary": "reports/execution_summary_${execution_id}.json"
  }
}
EOF
    
    log_info "Execution summary saved: $summary_file"
}

# Monitor running processes
monitor_processes() {
    log_header "Process Monitoring Dashboard"
    
    # Display current system resources
    echo "System Resources:"
    echo "=================="
    echo "CPU Usage: $(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)%"
    echo "Memory Usage: $(free | grep Mem | awk '{printf("%.1f%%", ($3/$2) * 100.0)}')"
    echo "Disk Usage: $(df -h / | awk 'NR==2{print $5}')"
    echo

    # Show recent executions
    echo "Recent Executions:"
    echo "=================="
    if [[ -d "$REPORTS_DIR" ]]; then
        find "$REPORTS_DIR" -name "execution_summary_*.json" -mtime -1 | head -5 | while read -r file; do
            if command -v jq >/dev/null 2>&1; then
                echo "$(jq -r '.timestamp + " | " + .process_name + " | " + .status + " | " + (.duration_seconds|tostring) + "s"' "$file")"
            else
                basename "$file"
            fi
        done
    else
        echo "No recent executions found"
    fi
    echo

    # Show active processes
    echo "Active Automation Processes:"
    echo "============================"
    pgrep -f "process-orchestrator.py" | while read -r pid; do
        echo "PID $pid: $(ps -p $pid -o cmd= | cut -c1-80)"
    done
}

# Interactive process selection
interactive_selection() {
    log_header "Interactive Process Selection"
    
    show_available_processes
    echo
    
    # Get available process names
    local processes=($(python3 << 'EOF'
import yaml
with open('${CONFIG_FILE}', 'r') as f:
    config = yaml.safe_load(f)
processes = config.get('processes', {})
print(' '.join(processes.keys()))
EOF
))
    
    if [[ ${#processes[@]} -eq 0 ]]; then
        log_error "No processes available"
        return 1
    fi
    
    echo "Select a process to execute:"
    select process in "${processes[@]}" "Monitor Processes" "Exit"; do
        case $process in
            "Monitor Processes")
                monitor_processes
                echo
                ;;
            "Exit")
                log_info "Goodbye!"
                break
                ;;
            "")
                log_warning "Invalid selection. Please try again."
                ;;
            *)
                if [[ -n "$process" ]]; then
                    echo
                    read -p "Environment (development/staging/production) [development]: " environment
                    environment=${environment:-development}
                    
                    echo
                    execute_process "$process" "$environment"
                    echo
                fi
                ;;
        esac
    done
}

# Health check
health_check() {
    log_header "Automation Framework Health Check"
    
    local health_status=0
    
    # Check configuration file
    if [[ -f "$CONFIG_FILE" ]]; then
        log_success "Configuration file: OK"
        
        # Validate YAML syntax
        if python3 -c "import yaml; yaml.safe_load(open('$CONFIG_FILE'))" 2>/dev/null; then
            log_success "Configuration syntax: OK"
        else
            log_error "Configuration syntax: INVALID"
            health_status=1
        fi
    else
        log_error "Configuration file: MISSING"
        health_status=1
    fi
    
    # Check Python environment
    if python3 -c "import yaml, asyncio" 2>/dev/null; then
        log_success "Python dependencies: OK"
    else
        log_error "Python dependencies: MISSING"
        health_status=1
    fi
    
    # Check required directories
    for dir in logs reports automation; do
        if [[ -d "${PROJECT_ROOT}/$dir" ]]; then
            log_success "Directory $dir: OK"
        else
            log_warning "Directory $dir: MISSING (will be created)"
        fi
    done
    
    # Check external services (optional)
    if command -v docker >/dev/null 2>&1; then
        if docker info >/dev/null 2>&1; then
            log_success "Docker: AVAILABLE"
        else
            log_warning "Docker: NOT RUNNING"
        fi
    else
        log_warning "Docker: NOT INSTALLED"
    fi
    
    # Overall health status
    if [[ $health_status -eq 0 ]]; then
        log_success "Automation framework is healthy"
    else
        log_error "Automation framework has issues"
    fi
    
    return $health_status
}

# Usage information
show_usage() {
    cat << EOF
Obl Claude Code - Automation Framework Runner

Usage: $0 [OPTIONS] [PROCESS_NAME]

OPTIONS:
    -h, --help              Show this help message
    -l, --list              List available processes
    -i, --interactive       Interactive process selection
    -m, --monitor          Monitor running processes
    -c, --health-check     Perform health check
    -e, --environment ENV   Specify environment (development/staging/production)
    -v, --validate PROCESS  Validate specific process configuration

EXAMPLES:
    $0 --interactive                           # Interactive mode
    $0 --list                                 # List available processes
    $0 full_deployment_pipeline               # Execute specific process
    $0 --environment staging deploy_app       # Execute with specific environment
    $0 --validate full_deployment_pipeline    # Validate process configuration
    $0 --health-check                        # Check framework health

ENVIRONMENT:
    The automation framework respects the following environment variables:
    - ENVIRONMENT: Target environment (development/staging/production)
    - LOG_LEVEL: Logging verbosity (DEBUG/INFO/WARNING/ERROR)
    - NOTIFICATION_WEBHOOK: Webhook URL for notifications

EOF
}

# Main execution function
main() {
    # Initialize environment
    init_environment
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -l|--list)
                show_available_processes
                exit 0
                ;;
            -i|--interactive)
                interactive_selection
                exit 0
                ;;
            -m|--monitor)
                monitor_processes
                exit 0
                ;;
            -c|--health-check)
                health_check
                exit $?
                ;;
            -e|--environment)
                ENVIRONMENT="$2"
                shift 2
                ;;
            -v|--validate)
                validate_process "$2"
                exit $?
                ;;
            -*)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
            *)
                # Process name provided
                PROCESS_NAME="$1"
                shift
                ;;
        esac
    done
    
    # If no process specified, show interactive selection
    if [[ -z "${PROCESS_NAME:-}" ]]; then
        interactive_selection
    else
        execute_process "$PROCESS_NAME" "${ENVIRONMENT:-development}"
    fi
}

# Handle interrupts gracefully
trap 'log_warning "Interrupted by user"; exit 130' INT TERM

# Execute main function with all arguments
main "$@"