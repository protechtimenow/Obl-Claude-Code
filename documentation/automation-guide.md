# Comprehensive Automation Guide

## Overview

This document provides an in-depth guide to the advanced automation framework implemented in the Obl Claude Code project. The framework is designed to handle enterprise-level automation processes with intelligent orchestration, comprehensive monitoring, and self-healing capabilities.

## Architecture Philosophy

### Core Principles

1. **Declarative Configuration**: All automation processes are defined through YAML configurations, enabling version control and easy modifications.

2. **Dependency-Aware Execution**: The orchestrator understands process dependencies and executes tasks in optimal order with parallel execution where possible.

3. **Intelligent Error Handling**: Multi-level retry mechanisms with exponential backoff and circuit breaker patterns.

4. **Comprehensive Observability**: Full logging, metrics, and tracing for all automated processes.

5. **Security-First Approach**: Built-in security scanning, secrets management, and compliance checking.

## Process Orchestration Engine

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Process Orchestrator                     │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐ │
│  │   Configuration │  │   Dependency    │  │     Resource    │ │
│  │     Manager     │  │     Resolver    │  │     Manager     │ │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘ │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐ │
│  │   Execution     │  │     State       │  │   Notification  │ │
│  │     Engine      │  │    Manager      │  │     Handler     │ │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘ │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐ │
│  │     Metrics     │  │     Logging     │  │      Error      │ │
│  │   Collector     │  │     System      │  │     Recovery    │ │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

### Configuration Management

#### Process Definition Structure

```yaml
processes:
  process_name:
    description: "Human-readable description"
    schedule: "0 2 * * 0"  # Optional: Cron format for scheduled execution
    environment: "production"  # Target environment
    timeout: 3600  # Global timeout in seconds
    retry_policy:
      max_retries: 3
      backoff_strategy: "exponential"  # linear, exponential, fixed
      initial_delay: 5
    notification_channels: ["slack", "email"]
    
    steps:
      - name: "step_identifier"
        command: "executable_command"
        dependencies: ["prerequisite_step1", "prerequisite_step2"]
        timeout: 600  # Step-specific timeout
        retry_count: 2  # Step-specific retries
        critical: true  # Process fails if critical step fails
        environment_variables:
          KEY1: "value1"
          KEY2: "value2"
        condition: "branch == 'main' and approved == true"  # Execution condition
        healthcheck:
          command: "curl -f http://localhost:8080/health"
          interval: 30
          retries: 3
```

#### Environment Configuration

Each environment (development, staging, production) has specific configurations:

```yaml
environments:
  production:
    database_url: "postgresql://prod_user:${DB_PASSWORD}@prod-db:5432/prod_db"
    api_endpoint: "https://api.example.com"
    resource_limits:
      cpu: "8"
      memory: "16Gi"
      storage: "100Gi"
    security_policies:
      - name: "network_isolation"
        enabled: true
      - name: "rbac_enforcement"
        enabled: true
    monitoring:
      prometheus_endpoint: "https://prometheus.prod.example.com"
      grafana_dashboard: "https://grafana.prod.example.com/d/automation"
```

### Intelligent Process Execution

#### Dependency Resolution Algorithm

The orchestrator uses a topological sort algorithm to resolve dependencies:

1. **Graph Construction**: Build directed acyclic graph (DAG) from process dependencies
2. **Cycle Detection**: Validate that no circular dependencies exist
3. **Parallel Optimization**: Identify steps that can run in parallel
4. **Resource Allocation**: Assign resources based on step requirements and availability

#### Execution Strategies

##### 1. Sequential Execution
```python
async def execute_sequential(steps):
    results = {}
    for step in steps:
        if step.condition and not evaluate_condition(step.condition):
            continue
        result = await execute_step_with_retry(step)
        results[step.name] = result
        if not result and step.critical:
            raise CriticalStepFailedException(step.name)
    return results
```

##### 2. Parallel Execution
```python
async def execute_parallel(step_groups):
    all_results = {}
    for group in step_groups:
        group_tasks = [execute_step_with_retry(step) for step in group]
        group_results = await asyncio.gather(*group_tasks, return_exceptions=True)
        all_results.update(dict(zip([s.name for s in group], group_results)))
    return all_results
```

#### Advanced Retry Mechanisms

##### Exponential Backoff with Jitter
```python
def calculate_retry_delay(attempt: int, config: RetryConfig) -> float:
    if config.backoff_strategy == "exponential":
        base_delay = config.initial_delay * (2 ** (attempt - 1))
        # Add jitter to prevent thundering herd
        jitter = random.uniform(0.1, 0.3) * base_delay
        return min(base_delay + jitter, config.max_delay)
    elif config.backoff_strategy == "linear":
        return config.initial_delay * attempt
    else:  # fixed
        return config.initial_delay
```

##### Circuit Breaker Pattern
```python
class CircuitBreaker:
    def __init__(self, failure_threshold=5, recovery_timeout=60):
        self.failure_threshold = failure_threshold
        self.recovery_timeout = recovery_timeout
        self.failure_count = 0
        self.last_failure_time = None
        self.state = "CLOSED"  # CLOSED, OPEN, HALF_OPEN
        
    async def call(self, func, *args, **kwargs):
        if self.state == "OPEN":
            if time.time() - self.last_failure_time > self.recovery_timeout:
                self.state = "HALF_OPEN"
            else:
                raise CircuitBreakerOpenException()
                
        try:
            result = await func(*args, **kwargs)
            if self.state == "HALF_OPEN":
                self.state = "CLOSED"
                self.failure_count = 0
            return result
        except Exception as e:
            self.failure_count += 1
            self.last_failure_time = time.time()
            if self.failure_count >= self.failure_threshold:
                self.state = "OPEN"
            raise
```

## CI/CD Pipeline Automation

### Multi-Stage Pipeline Architecture

#### Stage 1: Code Quality & Security Analysis
```bash
# Code quality metrics collection
sonarqube_analysis() {
    sonar-scanner \
        -Dsonar.projectKey="$PROJECT_KEY" \
        -Dsonar.sources=src/ \
        -Dsonar.tests=tests/ \
        -Dsonar.coverage.exclusions="**/*test*" \
        -Dsonar.qualitygate.wait=true
}

# Security vulnerability scanning
security_scan_comprehensive() {
    # Static analysis
    bandit -r src/ -f json -o reports/bandit.json
    
    # Dependency scanning
    safety check --json --output reports/safety.json
    
    # Container scanning
    trivy image --format json --output reports/trivy.json "$IMAGE_NAME"
    
    # Infrastructure scanning
    checkov --framework terraform --output json --output-file reports/checkov.json
}
```

#### Stage 2: Multi-Environment Testing
```bash
# Parallel test execution with different configurations
execute_test_matrix() {
    local environments=("python3.9" "python3.10" "python3.11")
    local databases=("postgresql" "mysql" "sqlite")
    
    for env in "${environments[@]}"; do
        for db in "${databases[@]}"; do
            {
                export TEST_ENV="$env"
                export TEST_DB="$db"
                pytest tests/ --maxfail=1 --tb=short \
                    --junitxml="reports/junit-${env}-${db}.xml"
            } &
        done
    done
    
    wait  # Wait for all background processes to complete
}
```

#### Stage 3: Intelligent Deployment

##### Blue-Green Deployment
```bash
deploy_blue_green() {
    local environment=$1
    local new_version=$2
    
    # Deploy to green environment
    kubectl apply -f k8s/green/ --namespace="$environment"
    
    # Wait for green deployment to be ready
    kubectl wait --for=condition=available --timeout=300s \
        deployment/app-green -n "$environment"
    
    # Run smoke tests against green environment
    if run_smoke_tests_green "$environment"; then
        # Switch traffic to green
        kubectl patch service app-service -n "$environment" \
            -p '{"spec":{"selector":{"version":"green"}}}'
        
        # Wait for traffic switch confirmation
        sleep 30
        
        # Run verification tests
        if verify_production_health "$environment"; then
            # Success - clean up blue environment
            kubectl delete deployment app-blue -n "$environment"
            log_success "Blue-green deployment completed successfully"
        else
            # Rollback to blue
            kubectl patch service app-service -n "$environment" \
                -p '{"spec":{"selector":{"version":"blue"}}}'
            log_error "Deployment verification failed - rolled back to blue"
            return 1
        fi
    else
        log_error "Green environment smoke tests failed"
        kubectl delete deployment app-green -n "$environment"
        return 1
    fi
}
```

##### Canary Deployment with Progressive Traffic Shifting
```bash
deploy_canary() {
    local environment=$1
    local canary_percentage_steps=(10 25 50 75 100)
    
    # Deploy canary version
    kubectl apply -f k8s/canary/ --namespace="$environment"
    
    for percentage in "${canary_percentage_steps[@]}"; do
        log_info "Shifting $percentage% traffic to canary"
        
        # Update Istio virtual service for traffic splitting
        kubectl patch virtualservice app-vs -n "$environment" --type='merge' -p="{
            \"spec\": {
                \"http\": [{
                    \"route\": [
                        {\"destination\": {\"host\": \"app-service\", \"subset\": \"stable\"}, \"weight\": $((100 - percentage))},
                        {\"destination\": {\"host\": \"app-service\", \"subset\": \"canary\"}, \"weight\": $percentage}
                    ]
                }]
            }
        }"
        
        # Monitor metrics for 5 minutes
        if ! monitor_canary_metrics "$environment" 300; then
            log_error "Canary metrics degraded - rolling back"
            rollback_canary "$environment"
            return 1
        fi
        
        # Progressive delay between traffic shifts
        sleep 180
    done
    
    log_success "Canary deployment completed successfully"
    cleanup_stable_deployment "$environment"
}
```

## Infrastructure as Code Automation

### Terraform Automation with State Management
```hcl
# terraform/environments/production/main.tf
module "vpc" {
  source = "../../modules/vpc"
  
  environment = var.environment
  vpc_cidr    = var.vpc_cidr
  
  # Automation-specific tags
  tags = merge(var.common_tags, {
    "automation:managed" = "true"
    "automation:process" = "infrastructure-deployment"
    "automation:version" = var.deployment_version
  })
}

# State backend configuration for automation
terraform {
  backend "s3" {
    bucket         = "terraform-state-automation"
    key            = "environments/production/terraform.tfstate"
    region         = "us-west-2"
    encrypt        = true
    dynamodb_table = "terraform-locks"
    
    # Automation service account access
    role_arn = "arn:aws:iam::ACCOUNT:role/TerraformAutomationRole"
  }
}
```

### Infrastructure Validation and Drift Detection
```bash
# Advanced infrastructure validation
validate_infrastructure() {
    local environment=$1
    
    # Terraform plan validation
    log_info "Validating Terraform configuration"
    cd "terraform/environments/$environment"
    
    terraform init -backend-config="key=environments/$environment/terraform.tfstate"
    terraform validate
    
    # Generate and analyze plan
    terraform plan -detailed-exitcode -out="plan.tfplan"
    local plan_exit_code=$?
    
    case $plan_exit_code in
        0)
            log_info "No infrastructure changes detected"
            ;;
        1)
            log_error "Terraform plan failed"
            return 1
            ;;
        2)
            log_warning "Infrastructure changes detected - requires approval"
            terraform show -json plan.tfplan > "plan.json"
            
            # Analyze changes for risk assessment
            python3 ../../../scripts/analyze-terraform-changes.py plan.json
            ;;
    esac
    
    # Infrastructure compliance checks
    log_info "Running infrastructure compliance checks"
    checkov --framework terraform --check CKV_AWS_* --output json \
        --output-file "../../../reports/infrastructure-compliance.json"
    
    # Cost analysis
    if command -v infracost &> /dev/null; then
        log_info "Analyzing infrastructure cost impact"
        infracost breakdown --path . --format json \
            --out-file "../../../reports/cost-analysis.json"
    fi
}

# Automated drift detection
detect_infrastructure_drift() {
    local environment=$1
    
    log_info "Detecting infrastructure drift for $environment"
    
    cd "terraform/environments/$environment"
    
    # Refresh state and detect drift
    terraform refresh
    terraform plan -detailed-exitcode > "../../../reports/drift-report-$environment.txt" 2>&1
    local drift_exit_code=$?
    
    if [[ $drift_exit_code -eq 2 ]]; then
        log_warning "Infrastructure drift detected in $environment"
        
        # Generate drift notification
        python3 ../../../scripts/generate-drift-alert.py \
            --environment "$environment" \
            --report "reports/drift-report-$environment.txt"
            
        return 1
    else
        log_success "No infrastructure drift detected in $environment"
        return 0
    fi
}
```

## Monitoring and Observability

### Comprehensive Metrics Collection
```python
# monitoring/metrics_collector.py
import prometheus_client
from dataclasses import dataclass
from typing import Dict, List
import asyncio
import time

@dataclass
class AutomationMetrics:
    process_duration: prometheus_client.Histogram
    process_success_rate: prometheus_client.Gauge
    step_execution_time: prometheus_client.Histogram
    error_count: prometheus_client.Counter
    resource_utilization: prometheus_client.Gauge

class MetricsCollector:
    def __init__(self):
        self.metrics = AutomationMetrics(
            process_duration=prometheus_client.Histogram(
                'automation_process_duration_seconds',
                'Duration of automation processes',
                ['process_name', 'environment', 'status']
            ),
            process_success_rate=prometheus_client.Gauge(
                'automation_process_success_rate',
                'Success rate of automation processes',
                ['process_name', 'environment']
            ),
            step_execution_time=prometheus_client.Histogram(
                'automation_step_duration_seconds',
                'Duration of individual process steps',
                ['process_name', 'step_name', 'status']
            ),
            error_count=prometheus_client.Counter(
                'automation_errors_total',
                'Total number of automation errors',
                ['process_name', 'step_name', 'error_type']
            ),
            resource_utilization=prometheus_client.Gauge(
                'automation_resource_utilization',
                'Resource utilization during automation',
                ['resource_type', 'process_name']
            )
        )
    
    async def collect_process_metrics(self, process_name: str, environment: str, 
                                    execution_func, *args, **kwargs):
        start_time = time.time()
        
        try:
            result = await execution_func(*args, **kwargs)
            status = "success"
            
            # Update success rate (simplified - would use sliding window in production)
            self.metrics.process_success_rate.labels(
                process_name=process_name, 
                environment=environment
            ).set(1.0)
            
        except Exception as e:
            status = "failure"
            result = None
            
            # Record error
            self.metrics.error_count.labels(
                process_name=process_name,
                step_name="process_level",
                error_type=type(e).__name__
            ).inc()
            
            # Update success rate
            self.metrics.process_success_rate.labels(
                process_name=process_name,
                environment=environment
            ).set(0.0)
            
            raise
            
        finally:
            duration = time.time() - start_time
            self.metrics.process_duration.labels(
                process_name=process_name,
                environment=environment,
                status=status
            ).observe(duration)
        
        return result
```

### Intelligent Alerting System
```yaml
# monitoring/alerting-rules.yml
groups:
  - name: automation.rules
    rules:
      - alert: AutomationProcessFailure
        expr: |
          automation_process_success_rate{environment="production"} == 0
        for: 0m
        labels:
          severity: critical
          team: platform
        annotations:
          summary: "Automation process {{ $labels.process_name }} failed in {{ $labels.environment }}"
          description: "The automation process {{ $labels.process_name }} has failed in {{ $labels.environment }} environment. Immediate investigation required."
          runbook_url: "https://runbooks.example.com/automation/process-failure"

      - alert: AutomationProcessDurationHigh
        expr: |
          histogram_quantile(0.95, rate(automation_process_duration_seconds_bucket[5m])) > 3600
        for: 15m
        labels:
          severity: warning
          team: platform
        annotations:
          summary: "Automation process {{ $labels.process_name }} taking longer than expected"
          description: "The 95th percentile duration for {{ $labels.process_name }} has exceeded 1 hour for the last 15 minutes."

      - alert: AutomationErrorRateHigh
        expr: |
          rate(automation_errors_total[5m]) > 0.1
        for: 10m
        labels:
          severity: warning
          team: platform
        annotations:
          summary: "High error rate in automation processes"
          description: "Automation process error rate has exceeded 0.1 errors/second for the last 10 minutes."
```

## Security and Compliance Automation

### Automated Security Scanning Pipeline
```python
# security/scanner.py
import asyncio
import subprocess
import json
from typing import List, Dict, Any
from dataclasses import dataclass

@dataclass
class SecurityFinding:
    severity: str
    title: str
    description: str
    file_path: str
    line_number: int
    cve_id: str = None
    remediation: str = None

class ComprehensiveSecurityScanner:
    def __init__(self):
        self.scanners = {
            'sast': self._run_sast_scan,
            'dependency': self._run_dependency_scan,
            'secrets': self._run_secrets_scan,
            'infrastructure': self._run_infrastructure_scan,
            'container': self._run_container_scan
        }
    
    async def run_comprehensive_scan(self) -> Dict[str, List[SecurityFinding]]:
        """Execute all security scans in parallel"""
        tasks = {
            scanner_type: scanner_func() 
            for scanner_type, scanner_func in self.scanners.items()
        }
        
        results = await asyncio.gather(*tasks.values(), return_exceptions=True)
        
        return dict(zip(tasks.keys(), results))
    
    async def _run_sast_scan(self) -> List[SecurityFinding]:
        """Static Application Security Testing"""
        findings = []
        
        # Bandit for Python
        try:
            result = subprocess.run([
                'bandit', '-r', '.', '-f', 'json'
            ], capture_output=True, text=True, check=False)
            
            if result.stdout:
                bandit_data = json.loads(result.stdout)
                for issue in bandit_data.get('results', []):
                    findings.append(SecurityFinding(
                        severity=issue['issue_severity'],
                        title=issue['test_name'],
                        description=issue['issue_text'],
                        file_path=issue['filename'],
                        line_number=issue['line_number'],
                        cve_id=issue.get('more_info', '')
                    ))
        except Exception as e:
            print(f"SAST scan error: {e}")
        
        return findings
    
    async def _run_dependency_scan(self) -> List[SecurityFinding]:
        """Scan for vulnerable dependencies"""
        findings = []
        
        # Safety for Python
        try:
            result = subprocess.run([
                'safety', 'check', '--json'
            ], capture_output=True, text=True, check=False)
            
            if result.stdout:
                safety_data = json.loads(result.stdout)
                for vuln in safety_data:
                    findings.append(SecurityFinding(
                        severity='HIGH',
                        title=f"Vulnerable dependency: {vuln['package']}",
                        description=vuln['advisory'],
                        file_path='requirements.txt',
                        line_number=0,
                        cve_id=vuln.get('id', ''),
                        remediation=f"Update to version {vuln.get('safe_versions', 'latest')}"
                    ))
        except Exception as e:
            print(f"Dependency scan error: {e}")
        
        return findings

    def generate_security_report(self, findings: Dict[str, List[SecurityFinding]]) -> str:
        """Generate comprehensive security report"""
        report = {
            'scan_timestamp': time.time(),
            'total_findings': sum(len(f) for f in findings.values()),
            'findings_by_type': {k: len(v) for k, v in findings.items()},
            'severity_breakdown': self._calculate_severity_breakdown(findings),
            'detailed_findings': findings,
            'recommendations': self._generate_recommendations(findings)
        }
        
        return json.dumps(report, indent=2, default=str)
```

## Performance Optimization and Resource Management

### Intelligent Resource Allocation
```python
# performance/resource_manager.py
import psutil
import asyncio
from typing import Dict, Optional
from dataclasses import dataclass

@dataclass
class ResourceLimits:
    cpu_percent: float
    memory_mb: int
    disk_gb: int
    network_mbps: int

class AdaptiveResourceManager:
    def __init__(self):
        self.baseline_metrics = self._collect_baseline_metrics()
        self.current_allocations: Dict[str, ResourceLimits] = {}
        
    def _collect_baseline_metrics(self) -> Dict[str, float]:
        """Collect system baseline metrics"""
        return {
            'cpu_usage': psutil.cpu_percent(interval=1),
            'memory_usage': psutil.virtual_memory().percent,
            'disk_usage': psutil.disk_usage('/').percent,
            'network_io': sum(psutil.net_io_counters()[:2])
        }
    
    async def allocate_resources_intelligently(self, 
                                             process_name: str, 
                                             estimated_requirements: ResourceLimits,
                                             priority: str = "normal") -> ResourceLimits:
        """Intelligently allocate resources based on system capacity and priority"""
        
        current_usage = self._get_current_usage()
        available_resources = self._calculate_available_resources(current_usage)
        
        # Adjust allocation based on priority and availability
        if priority == "high":
            multiplier = 1.2
        elif priority == "low":
            multiplier = 0.8
        else:
            multiplier = 1.0
        
        allocated = ResourceLimits(
            cpu_percent=min(
                estimated_requirements.cpu_percent * multiplier,
                available_resources['cpu'] * 0.7  # Reserve 30% for system
            ),
            memory_mb=min(
                estimated_requirements.memory_mb * multiplier,
                available_resources['memory'] * 0.8  # Reserve 20% for system
            ),
            disk_gb=estimated_requirements.disk_gb,  # Disk is less critical for allocation
            network_mbps=estimated_requirements.network_mbps
        )
        
        self.current_allocations[process_name] = allocated
        return allocated
    
    def _get_current_usage(self) -> Dict[str, float]:
        """Get current resource usage"""
        return {
            'cpu': psutil.cpu_percent(interval=0.1),
            'memory': psutil.virtual_memory().percent,
            'disk': psutil.disk_usage('/').percent
        }
    
    def _calculate_available_resources(self, current_usage: Dict[str, float]) -> Dict[str, float]:
        """Calculate available resources for allocation"""
        return {
            'cpu': max(0, 100 - current_usage['cpu']),
            'memory': max(0, 100 - current_usage['memory']),
            'disk': max(0, 100 - current_usage['disk'])
        }
```

## Advanced Error Handling and Recovery

### Self-Healing Process Implementation
```python
# recovery/self_healing.py
import asyncio
import logging
from enum import Enum
from typing import Dict, List, Callable, Any
from dataclasses import dataclass

class FailureType(Enum):
    NETWORK_TIMEOUT = "network_timeout"
    RESOURCE_EXHAUSTION = "resource_exhaustion"  
    DEPENDENCY_FAILURE = "dependency_failure"
    CONFIGURATION_ERROR = "configuration_error"
    SERVICE_UNAVAILABLE = "service_unavailable"

@dataclass
class RecoveryAction:
    action_type: str
    action_function: Callable
    success_criteria: Callable
    max_attempts: int = 3
    backoff_multiplier: float = 2.0

class SelfHealingOrchestrator:
    def __init__(self):
        self.recovery_strategies: Dict[FailureType, List[RecoveryAction]] = {
            FailureType.NETWORK_TIMEOUT: [
                RecoveryAction(
                    "retry_with_backoff",
                    self._retry_with_exponential_backoff,
                    self._check_network_connectivity,
                    max_attempts=5
                ),
                RecoveryAction(
                    "switch_endpoint",
                    self._switch_to_backup_endpoint,
                    self._verify_endpoint_health,
                    max_attempts=3
                )
            ],
            FailureType.RESOURCE_EXHAUSTION: [
                RecoveryAction(
                    "cleanup_resources",
                    self._cleanup_temporary_resources,
                    self._check_resource_availability,
                    max_attempts=2
                ),
                RecoveryAction(
                    "scale_resources",
                    self._request_additional_resources,
                    self._verify_resource_scaling,
                    max_attempts=1
                )
            ],
            FailureType.SERVICE_UNAVAILABLE: [
                RecoveryAction(
                    "restart_service",
                    self._restart_failed_service,
                    self._verify_service_health,
                    max_attempts=2
                ),
                RecoveryAction(
                    "failover_service",
                    self._failover_to_backup_service,
                    self._verify_backup_service,
                    max_attempts=1
                )
            ]
        }
    
    async def attempt_recovery(self, failure_type: FailureType, 
                             context: Dict[str, Any]) -> bool:
        """Attempt automated recovery from failure"""
        
        logging.info(f"Attempting recovery for failure type: {failure_type}")
        
        strategies = self.recovery_strategies.get(failure_type, [])
        
        for strategy in strategies:
            logging.info(f"Trying recovery strategy: {strategy.action_type}")
            
            for attempt in range(strategy.max_attempts):
                try:
                    # Execute recovery action
                    await strategy.action_function(context, attempt)
                    
                    # Wait before checking success criteria
                    await asyncio.sleep(min(5 * (strategy.backoff_multiplier ** attempt), 60))
                    
                    # Check if recovery was successful
                    if await strategy.success_criteria(context):
                        logging.info(f"Recovery successful using strategy: {strategy.action_type}")
                        return True
                        
                except Exception as e:
                    logging.warning(f"Recovery attempt {attempt + 1} failed: {str(e)}")
                    
            logging.warning(f"Strategy {strategy.action_type} failed after {strategy.max_attempts} attempts")
        
        logging.error(f"All recovery strategies failed for failure type: {failure_type}")
        return False
    
    async def _retry_with_exponential_backoff(self, context: Dict[str, Any], attempt: int):
        """Retry failed operation with exponential backoff"""
        delay = 2 ** attempt
        await asyncio.sleep(delay)
        # Re-execute the original failed operation
        if 'retry_function' in context:
            await context['retry_function']()
    
    async def _cleanup_temporary_resources(self, context: Dict[str, Any], attempt: int):
        """Clean up temporary resources to free memory/storage"""
        import gc
        import tempfile
        import shutil
        
        # Force garbage collection
        gc.collect()
        
        # Clean temporary files
        temp_dir = tempfile.gettempdir()
        for item in os.listdir(temp_dir):
            if item.startswith('automation_'):
                try:
                    item_path = os.path.join(temp_dir, item)
                    if os.path.isfile(item_path):
                        os.remove(item_path)
                    elif os.path.isdir(item_path):
                        shutil.rmtree(item_path)
                except Exception:
                    pass  # Continue cleanup even if some items fail
    
    async def _restart_failed_service(self, context: Dict[str, Any], attempt: int):
        """Restart a failed service"""
        service_name = context.get('service_name')
        if service_name:
            subprocess.run(['systemctl', 'restart', service_name], check=True)
```

This comprehensive automation framework provides enterprise-grade capabilities with intelligent process orchestration, advanced error handling, comprehensive monitoring, and self-healing mechanisms. The framework is designed to handle complex multi-step automation processes with high reliability and observability.