#!/usr/bin/env python3
"""
OBL.DEV Webhook Client
Test client for webhook communication
"""

import asyncio
import aiohttp
import json
import argparse
import time
from datetime import datetime

class WebhookClient:
    def __init__(self, base_url="http://localhost:8080"):
        self.base_url = base_url
        
    async def send_obl_webhook(self, task_data):
        """Send a webhook to simulate obl.dev communication"""
        url = f"{self.base_url}/webhook/obl-dev"
        
        payload = {
            "action": "task_request",
            "task": {
                "id": f"task_{int(time.time())}",
                "prompt": task_data.get("prompt", "Test task"),
                "priority": task_data.get("priority", "high"),
                "context": task_data.get("context", "Test context")
            },
            "timestamp": datetime.utcnow().isoformat()
        }
        
        async with aiohttp.ClientSession() as session:
            try:
                async with session.post(url, json=payload) as response:
                    result = await response.json()
                    print(f"✅ OBL webhook sent: {response.status}")
                    print(f"📝 Response: {result}")
                    return result
            except Exception as e:
                print(f"❌ Error sending OBL webhook: {e}")
                return None
    
    async def send_github_webhook(self, event_type="push"):
        """Send a GitHub webhook simulation"""
        url = f"{self.base_url}/webhook/github"
        
        if event_type == "push":
            payload = {
                "ref": "refs/heads/main",
                "repository": {
                    "name": "Obl-Claude-Code",
                    "full_name": "protechtimenow/Obl-Claude-Code"
                },
                "commits": [
                    {
                        "id": "abc123",
                        "message": "Test commit with deploy trigger",
                        "timestamp": datetime.utcnow().isoformat()
                    }
                ]
            }
        else:
            payload = {
                "workflow_run": {
                    "name": "OBL.DEV Sync",
                    "status": "completed",
                    "conclusion": "success"
                }
            }
        
        headers = {"X-GitHub-Event": event_type}
        
        async with aiohttp.ClientSession() as session:
            try:
                async with session.post(url, json=payload, headers=headers) as response:
                    result = await response.json()
                    print(f"✅ GitHub webhook sent: {response.status}")
                    print(f"📝 Response: {result}")
                    return result
            except Exception as e:
                print(f"❌ Error sending GitHub webhook: {e}")
                return None
    
    async def check_status(self):
        """Check webhook server status"""
        url = f"{self.base_url}/status"
        
        async with aiohttp.ClientSession() as session:
            try:
                async with session.get(url) as response:
                    result = await response.json()
                    print(f"🌐 Server Status ({response.status}):")
                    print(json.dumps(result, indent=2))
                    return result
            except Exception as e:
                print(f"❌ Error checking status: {e}")
                return None
    
    async def health_check(self):
        """Perform health check"""
        url = f"{self.base_url}/"
        
        async with aiohttp.ClientSession() as session:
            try:
                async with session.get(url) as response:
                    result = await response.json()
                    print(f"💚 Health Check ({response.status}):")
                    print(json.dumps(result, indent=2))
                    return result
            except Exception as e:
                print(f"❌ Error in health check: {e}")
                return None

async def main():
    parser = argparse.ArgumentParser(description="OBL.DEV Webhook Test Client")
    parser.add_argument("--url", default="http://localhost:8080", help="Webhook server URL")
    parser.add_argument("--action", choices=["status", "health", "obl", "github", "test-all"], 
                       default="test-all", help="Action to perform")
    parser.add_argument("--prompt", default="Test Claude integration", help="Prompt for OBL webhook")
    
    args = parser.parse_args()
    
    client = WebhookClient(args.url)
    
    if args.action == "status":
        await client.check_status()
    elif args.action == "health":
        await client.health_check()
    elif args.action == "obl":
        await client.send_obl_webhook({"prompt": args.prompt})
    elif args.action == "github":
        await client.send_github_webhook("push")
    elif args.action == "test-all":
        print("🧪 Testing all webhook endpoints...")
        print("\n1. Health Check:")
        await client.health_check()
        
        print("\n2. Status Check:")
        await client.check_status()
        
        print("\n3. OBL.DEV Webhook:")
        await client.send_obl_webhook({
            "prompt": "Create a simple web page for obl.dev",
            "priority": "high",
            "context": "Testing webhook integration"
        })
        
        print("\n4. GitHub Webhook:")
        await client.send_github_webhook("push")
        
        print("\n✅ All tests completed!")

if __name__ == "__main__":
    asyncio.run(main())