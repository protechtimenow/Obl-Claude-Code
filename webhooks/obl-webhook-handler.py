#!/usr/bin/env python3
"""
OBL.DEV Webhook Handler
Establishes direct communication between web and AI endpoints
"""

import os
import json
import asyncio
import aiohttp
from aiohttp import web, ClientSession
import logging
from datetime import datetime
import hmac
import hashlib

# Configuration
CLAUDE_API_KEY = os.getenv('ANTHROPIC_API_KEY')
GITHUB_TOKEN = os.getenv('GITHUB_TOKEN')
WEBHOOK_SECRET = os.getenv('WEBHOOK_SECRET', 'obl-dev-secret')
PORT = int(os.getenv('WEBHOOK_PORT', 8080))

# Logging setup
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class OBLWebhookHandler:
    def __init__(self):
        self.app = web.Application()
        self.setup_routes()
        
    def setup_routes(self):
        """Setup webhook endpoints"""
        self.app.router.add_post('/webhook/obl-dev', self.handle_obl_webhook)
        self.app.router.add_post('/webhook/claude', self.handle_claude_webhook)
        self.app.router.add_post('/webhook/github', self.handle_github_webhook)
        self.app.router.add_get('/status', self.status_endpoint)
        self.app.router.add_get('/', self.health_check)
        
    async def health_check(self, request):
        """Health check endpoint"""
        return web.json_response({
            "status": "operational",
            "service": "OBL.DEV Webhook Handler",
            "timestamp": datetime.utcnow().isoformat(),
            "endpoints": [
                "/webhook/obl-dev",
                "/webhook/claude", 
                "/webhook/github",
                "/status"
            ]
        })
    
    async def status_endpoint(self, request):
        """Status endpoint for monitoring"""
        return web.json_response({
            "webhook_status": "active",
            "claude_api": "connected" if CLAUDE_API_KEY else "disconnected",
            "github_api": "connected" if GITHUB_TOKEN else "disconnected",
            "last_activity": datetime.utcnow().isoformat()
        })
    
    def verify_signature(self, payload, signature):
        """Verify webhook signature"""
        if not signature:
            return False
        
        expected_signature = hmac.new(
            WEBHOOK_SECRET.encode('utf-8'),
            payload,
            hashlib.sha256
        ).hexdigest()
        
        return hmac.compare_digest(f"sha256={expected_signature}", signature)
    
    async def handle_obl_webhook(self, request):
        """Handle webhooks from obl.dev"""
        try:
            payload = await request.read()
            signature = request.headers.get('X-Hub-Signature-256')
            
            # Verify signature
            if not self.verify_signature(payload, signature):
                logger.warning("Invalid webhook signature from obl.dev")
                return web.json_response({"error": "Invalid signature"}, status=401)
            
            data = json.loads(payload)
            logger.info(f"Received obl.dev webhook: {data.get('action', 'unknown')}")
            
            # Process different webhook types
            action = data.get('action')
            
            if action == 'task_request':
                await self.process_task_request(data)
            elif action == 'deployment_trigger':
                await self.trigger_deployment(data)
            elif action == 'status_update':
                await self.update_status(data)
            else:
                logger.info(f"Unknown action: {action}")
            
            return web.json_response({"status": "processed", "action": action})
            
        except Exception as e:
            logger.error(f"Error handling obl.dev webhook: {e}")
            return web.json_response({"error": str(e)}, status=500)
    
    async def handle_claude_webhook(self, request):
        """Handle responses from Claude API"""
        try:
            data = await request.json()
            logger.info("Received Claude API response")
            
            # Process Claude response
            task_id = data.get('task_id')
            response = data.get('response')
            
            if task_id and response:
                await self.relay_to_obl_dev({
                    "type": "claude_response",
                    "task_id": task_id,
                    "response": response,
                    "timestamp": datetime.utcnow().isoformat()
                })
            
            return web.json_response({"status": "received"})
            
        except Exception as e:
            logger.error(f"Error handling Claude webhook: {e}")
            return web.json_response({"error": str(e)}, status=500)
    
    async def handle_github_webhook(self, request):
        """Handle GitHub webhooks"""
        try:
            data = await request.json()
            event = request.headers.get('X-GitHub-Event')
            
            logger.info(f"Received GitHub webhook: {event}")
            
            if event == 'push':
                await self.process_github_push(data)
            elif event == 'workflow_run':
                await self.process_workflow_run(data)
            
            return web.json_response({"status": "processed"})
            
        except Exception as e:
            logger.error(f"Error handling GitHub webhook: {e}")
            return web.json_response({"error": str(e)}, status=500)
    
    async def process_task_request(self, data):
        """Process task request from obl.dev"""
        task = data.get('task', {})
        task_id = task.get('id')
        prompt = task.get('prompt')
        
        if not prompt:
            logger.error("No prompt in task request")
            return
        
        logger.info(f"Processing task {task_id}: {prompt[:50]}...")
        
        # Send to Claude API
        claude_response = await self.send_to_claude(prompt, task_id)
        
        # Store task status
        await self.update_task_status(task_id, "processing", claude_response)
    
    async def send_to_claude(self, prompt, task_id):
        """Send request to Claude API"""
        if not CLAUDE_API_KEY:
            logger.error("Claude API key not configured")
            return None
        
        try:
            async with ClientSession() as session:
                headers = {
                    'Authorization': f'Bearer {CLAUDE_API_KEY}',
                    'Content-Type': 'application/json'
                }
                
                payload = {
                    "model": "claude-3-5-sonnet-20241022",
                    "max_tokens": 4096,
                    "messages": [
                        {
                            "role": "user",
                            "content": prompt
                        }
                    ]
                }
                
                async with session.post(
                    'https://api.anthropic.com/v1/messages',
                    headers=headers,
                    json=payload
                ) as response:
                    if response.status == 200:
                        result = await response.json()
                        content = result.get('content', [])
                        if content and content[0].get('type') == 'text':
                            return content[0].get('text')
                    else:
                        logger.error(f"Claude API error: {response.status}")
                        return None
                        
        except Exception as e:
            logger.error(f"Error sending to Claude: {e}")
            return None
    
    async def relay_to_obl_dev(self, data):
        """Relay response back to obl.dev"""
        # This would send the response back to obl.dev
        # Implementation depends on obl.dev webhook endpoint
        logger.info(f"Relaying to obl.dev: {data.get('type', 'unknown')}")
        
        # Save to local bridge for terminal access
        await self.save_to_bridge(data)
    
    async def save_to_bridge(self, data):
        """Save data to Claude bridge for terminal access"""
        bridge_file = '.claude/bridge/webhook-data.json'
        
        try:
            # Read existing data
            existing_data = []
            if os.path.exists(bridge_file):
                with open(bridge_file, 'r') as f:
                    existing_data = json.load(f)
            
            # Append new data
            existing_data.append(data)
            
            # Keep only last 100 entries
            if len(existing_data) > 100:
                existing_data = existing_data[-100:]
            
            # Write back
            os.makedirs(os.path.dirname(bridge_file), exist_ok=True)
            with open(bridge_file, 'w') as f:
                json.dump(existing_data, f, indent=2)
                
        except Exception as e:
            logger.error(f"Error saving to bridge: {e}")
    
    async def trigger_deployment(self, data):
        """Trigger deployment based on webhook"""
        target = data.get('target', 'railway')
        
        # Execute deployment script
        deployment_script = f'./scripts/deploy-{target}'
        
        if os.path.exists(deployment_script):
            logger.info(f"Triggering {target} deployment")
            # This would execute the deployment script
            # For now, just log the action
            await self.save_to_bridge({
                "type": "deployment_triggered",
                "target": target,
                "timestamp": datetime.utcnow().isoformat()
            })
        else:
            logger.error(f"Deployment script not found: {deployment_script}")
    
    async def update_task_status(self, task_id, status, data=None):
        """Update task status"""
        status_update = {
            "type": "task_status",
            "task_id": task_id,
            "status": status,
            "timestamp": datetime.utcnow().isoformat()
        }
        
        if data:
            status_update["data"] = data
        
        await self.save_to_bridge(status_update)
    
    async def process_github_push(self, data):
        """Process GitHub push webhook"""
        commits = data.get('commits', [])
        repository = data.get('repository', {})
        
        logger.info(f"GitHub push to {repository.get('name')}: {len(commits)} commits")
        
        # Check if push contains specific triggers
        for commit in commits:
            message = commit.get('message', '').lower()
            if 'deploy' in message or 'webhook' in message:
                await self.save_to_bridge({
                    "type": "github_trigger",
                    "action": "deploy",
                    "commit": commit.get('id'),
                    "message": commit.get('message'),
                    "timestamp": datetime.utcnow().isoformat()
                })
    
    async def process_workflow_run(self, data):
        """Process GitHub workflow run webhook"""
        workflow = data.get('workflow_run', {})
        status = workflow.get('status')
        conclusion = workflow.get('conclusion')
        
        logger.info(f"GitHub workflow {workflow.get('name')}: {status}/{conclusion}")
        
        await self.save_to_bridge({
            "type": "workflow_status",
            "workflow": workflow.get('name'),
            "status": status,
            "conclusion": conclusion,
            "timestamp": datetime.utcnow().isoformat()
        })

def main():
    """Main function to run the webhook handler"""
    handler = OBLWebhookHandler()
    
    logger.info(f"Starting OBL.DEV Webhook Handler on port {PORT}")
    logger.info("Webhook endpoints:")
    logger.info(f"  - POST /webhook/obl-dev")
    logger.info(f"  - POST /webhook/claude") 
    logger.info(f"  - POST /webhook/github")
    logger.info(f"  - GET /status")
    
    web.run_app(handler.app, host='0.0.0.0', port=PORT)

if __name__ == '__main__':
    main()