#!/bin/bash
# Claude Code Integration Setup Script
# This script configures the repository for optimal Claude Code workflow

set -e

echo "🚀 Setting up Claude Code integration for Obl Automation Framework"

# Create necessary directories
echo "📁 Creating directory structure..."
mkdir -p .claude
mkdir -p scripts/claude-tasks
mkdir -p environments/{development,staging,production}
mkdir -p documentation/claude-workflows
mkdir -p reports
mkdir -p logs

# Set up Claude Code context file
echo "📝 Creating Claude Code context file..."
cat << 'EOF' > .claude/context.md
# Claude Code Project Context

## Project: Obl Claude Code - Advanced Automation Framework

### Current State
- **Purpose**: Enterprise-grade automation framework with comprehensive process orchestration
- **Architecture**: Python-based with YAML configuration, Docker-ready
- **Integration**: Full GitHub Actions CI/CD pipeline, monitoring, security automation

### Key Components
1. **Process Orchestrator** (`automation/process-orchestrator.py`)
   - Async execution engine
   - Dependency resolution
   - Intelligent retry mechanisms
   - Comprehensive logging and reporting

2. **Configuration Management** (`automation/config.yaml`)
   - Multi-environment support
   - Process definitions with dependencies
   - Notification and monitoring settings

3. **CI/CD Integration** (`.github/workflows/`)
   - Automated testing and deployment
   - Security scans and code quality checks
   - Claude Code integration workflows

### Current Priorities
1. Enhanced error handling and recovery
2. Performance optimization for large-scale deployments
3. Advanced monitoring and alerting
4. Security hardening and compliance

### Development Guidelines
- Follow async/await patterns for all I/O operations
- Include comprehensive logging for debugging
- Maintain environment-specific configurations
- Ensure all processes have proper dependency chains
- Document all configuration changes

### Recent Changes
- Initial framework setup with core orchestration engine
- GitHub Actions integration for CI/CD
- Comprehensive configuration structure
- Claude Code workflow optimization

EOF

# Create Claude Code task definitions
echo "⚡ Setting up Claude Code task definitions..."
cat << 'EOF' > scripts/claude-tasks/common-tasks.sh
#!/bin/bash
# Common Claude Code Tasks for Automation Framework

# Development Tasks
claude_analyze_code() {
    echo "Analyzing codebase with Claude Code..."
    claude-code "Analyze the entire automation framework and provide optimization suggestions"
}

claude_add_feature() {
    local feature_name="$1"
    echo "Adding new feature: $feature_name"
    claude-code "Add a new automation process for $feature_name to the framework"
}

claude_security_audit() {
    echo "Running security audit with Claude Code..."
    claude-code "Perform comprehensive security audit of all Python scripts and configurations"
}

# Deployment Tasks
claude_deploy_staging() {
    echo "Deploying to staging with Claude Code..."
    claude-code "Deploy the automation framework to staging environment with health checks"
}

claude_deploy_production() {
    echo "Production deployment with Claude Code..."
    claude-code "Execute production deployment with blue-green strategy and rollback capability"
}

# Monitoring Tasks
claude_health_check() {
    echo "Running health checks with Claude Code..."
    claude-code "Check health of all automation processes and generate status report"
}

claude_performance_analysis() {
    echo "Performance analysis with Claude Code..."
    claude-code "Analyze performance metrics and suggest optimizations"
}

# Maintenance Tasks
claude_update_dependencies() {
    echo "Updating dependencies with Claude Code..."
    claude-code "Update all Python dependencies and test for compatibility"
}

claude_generate_docs() {
    echo "Generating documentation with Claude Code..."
    claude-code "Generate comprehensive API documentation for all modules"
}

# Usage function
show_claude_tasks() {
    echo "Available Claude Code Tasks:"
    echo "  claude_analyze_code          - Analyze codebase for improvements"
    echo "  claude_add_feature <name>    - Add new automation feature"
    echo "  claude_security_audit        - Comprehensive security audit"
    echo "  claude_deploy_staging        - Deploy to staging environment"
    echo "  claude_deploy_production     - Deploy to production environment"
    echo "  claude_health_check          - Check system health"
    echo "  claude_performance_analysis  - Analyze performance metrics"
    echo "  claude_update_dependencies   - Update all dependencies"
    echo "  claude_generate_docs         - Generate documentation"
}

EOF

# Create environment-specific Claude configurations
echo "🌍 Setting up environment configurations..."

# Development environment
cat << 'EOF' > environments/development/claude-config.json
{
  "environment": "development",
  "claude_code_settings": {
    "commit_directly": true,
    "run_tests_before_commit": true,
    "auto_format_code": true,
    "verbose_logging": true
  },
  "automation_settings": {
    "timeout_multiplier": 0.5,
    "retry_count": 5,
    "enable_debug_mode": true
  },
  "allowed_operations": [
    "code_analysis",
    "feature_development", 
    "testing",
    "documentation",
    "configuration_changes"
  ]
}
EOF

# Staging environment
cat << 'EOF' > environments/staging/claude-config.json
{
  "environment": "staging",
  "claude_code_settings": {
    "commit_directly": false,
    "create_pull_request": true,
    "run_tests_before_commit": true,
    "require_review": true
  },
  "automation_settings": {
    "timeout_multiplier": 1.0,
    "retry_count": 3,
    "enable_debug_mode": false
  },
  "allowed_operations": [
    "integration_testing",
    "performance_testing",
    "security_scanning",
    "deployment_validation"
  ]
}
EOF

# Production environment
cat << 'EOF' > environments/production/claude-config.json
{
  "environment": "production",
  "claude_code_settings": {
    "commit_directly": false,
    "create_pull_request": true,
    "require_approval": true,
    "emergency_access": true
  },
  "automation_settings": {
    "timeout_multiplier": 2.0,
    "retry_count": 1,
    "enable_monitoring": true
  },
  "allowed_operations": [
    "monitoring",
    "emergency_fixes",
    "performance_monitoring",
    "security_monitoring"
  ]
}
EOF

# Create Claude Code workflow documentation
echo "📚 Creating workflow documentation..."
cat << 'EOF' > documentation/claude-workflows/development-workflow.md
# Claude Code Development Workflow

## Daily Development Tasks

### 1. Morning Setup
```bash
# Check project status
claude-code "What changes were made since yesterday and what should I focus on today?"

# Analyze recent commits
claude-code "Review the last 5 commits and suggest next development priorities"
```

### 2. Feature Development
```bash
# Start new feature
claude-code "Create a new branch for implementing user authentication"

# Implement feature
claude-code "Implement JWT-based authentication with proper error handling"

# Test implementation
claude-code "Write comprehensive tests for the authentication feature"
```

### 3. Code Quality
```bash
# Code review
claude-code "Review my recent changes and suggest improvements"

# Security check
claude-code "Scan for security vulnerabilities in authentication code"

# Performance optimization
claude-code "Optimize the authentication flow for better performance"
```

### 4. Documentation
```bash
# Update docs
claude-code "Update API documentation for new authentication endpoints"

# Generate examples
claude-code "Create usage examples for the authentication feature"
```

### 5. Integration & Deployment
```bash
# Integration testing
claude-code "Run integration tests and create deployment checklist"

# Staging deployment
claude-code "Deploy to staging and run smoke tests"

# Production deployment (when ready)
claude-code "Execute blue-green deployment to production"
```

## Best Practices

1. **Always check current branch**: `git branch` before starting Claude Code tasks
2. **Use descriptive commands**: Be specific about what you want Claude Code to do
3. **Review changes**: Always review Claude Code's changes before committing
4. **Test first**: Run tests before any deployment operations
5. **Document changes**: Update documentation when adding new features

## Emergency Procedures

### Hotfix Workflow
```bash
# Create hotfix branch
claude-code "Create hotfix branch for critical security vulnerability"

# Implement fix
claude-code "Fix the SQL injection vulnerability in user queries"

# Fast-track testing
claude-code "Run security tests and prepare emergency deployment"

# Emergency deployment
claude-code "Deploy hotfix to production with rollback plan"
```

### Rollback Workflow
```bash
# Quick rollback
claude-code "Rollback last deployment due to performance issues"

# Investigate issues
claude-code "Analyze logs to identify root cause of performance degradation"

# Plan recovery
claude-code "Create recovery plan for failed deployment"
```

EOF

# Set up Git hooks for Claude Code integration
echo "🪝 Setting up Git hooks..."
mkdir -p .git/hooks

cat << 'EOF' > .git/hooks/pre-commit
#!/bin/bash
# Pre-commit hook optimized for Claude Code workflow

echo "🔍 Running pre-commit checks..."

# Check if this is a Claude Code commit
if [[ "$GIT_AUTHOR_NAME" == *"claude"* ]] || [[ "$CLAUDE_CODE_COMMIT" == "true" ]]; then
    echo "✅ Claude Code commit detected - running enhanced checks"
    
    # Run code quality checks
    if command -v pylint >/dev/null 2>&1; then
        echo "Running pylint..."
        pylint automation/ || echo "⚠️  Pylint warnings detected"
    fi
    
    # Run security checks if bandit is available
    if command -v bandit >/dev/null 2>&1; then
        echo "Running security scan..."
        bandit -r automation/ || echo "⚠️  Security issues detected"
    fi
fi

echo "✅ Pre-commit checks completed"
EOF

chmod +x .git/hooks/pre-commit

# Create quick start script
echo "🚀 Creating quick start script..."
cat << 'EOF' > scripts/claude-quick-start.sh
#!/bin/bash
# Quick start script for Claude Code integration

echo "🎯 Claude Code Quick Start for Obl Automation Framework"
echo ""
echo "Common commands to get started:"
echo ""
echo "📊 Project Analysis:"
echo "  claude-code \"Analyze the current state of the automation framework\""
echo ""
echo "🔧 Development:"
echo "  claude-code \"Add error handling to the process orchestrator\""
echo "  claude-code \"Optimize the async execution performance\""
echo ""
echo "🔒 Security:"
echo "  claude-code \"Perform security audit of all Python scripts\""
echo ""
echo "🚀 Deployment:"
echo "  claude-code \"Prepare deployment to staging environment\""
echo ""
echo "📝 Documentation:"
echo "  claude-code \"Generate API documentation for all modules\""
echo ""
echo "💡 Try any of these commands, or ask Claude Code for help with:"
echo "  claude-code \"What should I work on next for this automation framework?\""
echo ""

EOF

chmod +x scripts/claude-quick-start.sh
chmod +x scripts/claude-tasks/common-tasks.sh

# Final setup
echo "🔧 Finalizing setup..."

# Install Python dependencies if requirements.txt exists
if [ -f "requirements.txt" ]; then
    echo "📦 Installing Python dependencies..."
    pip install -r requirements.txt
else
    echo "📝 Creating requirements.txt..."
    cat << 'EOF' > requirements.txt
# Core dependencies for automation framework
pyyaml>=6.0
asyncio>=3.4.3
logging>=0.4.9.6
pytest>=7.0.0
pylint>=2.17.0
bandit>=1.7.0
black>=23.0.0
isort>=5.12.0
mypy>=1.0.0

# Optional dependencies for enhanced features
prometheus-client>=0.16.0
requests>=2.28.0
docker>=6.0.0
kubernetes>=25.0.0
EOF
fi

echo "✅ Claude Code integration setup complete!"
echo ""
echo "🎯 Next steps:"
echo "1. Run: ./scripts/claude-quick-start.sh"
echo "2. Try: claude-code \"Show me the current automation framework status\""
echo "3. Explore: ./scripts/claude-tasks/common-tasks.sh"
echo ""
echo "📚 Documentation available in:"
echo "  - claude-code-setup.md"
echo "  - documentation/claude-workflows/"
echo ""
echo "Happy automating with Claude Code! 🚀"