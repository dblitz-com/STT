#!/usr/bin/env python3
"""
🚀 Zeus VLA Unified Launcher & Monitor
Starts all services, monitors health, shows unified status
"""

import subprocess
import time
import sys
import os
import signal
import threading
import requests
from pathlib import Path

class ZeusLauncher:
    def __init__(self):
        self.processes = {}
        self.running = True
        self.base_dir = Path(__file__).parent
        
    def log(self, message, service="LAUNCHER"):
        timestamp = time.strftime("%H:%M:%S")
        print(f"[{timestamp}] {service}: {message}")
        
    def start_service(self, name, command, cwd=None):
        """Start a service process"""
        try:
            if cwd is None:
                cwd = self.base_dir
                
            self.log(f"🚀 Starting {name}...", name)
            process = subprocess.Popen(
                command,
                shell=True,
                cwd=cwd,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                universal_newlines=True,
                bufsize=1
            )
            
            self.processes[name] = {
                'process': process,
                'command': command,
                'cwd': cwd,
                'start_time': time.time()
            }
            
            # Start log monitor thread
            threading.Thread(
                target=self._monitor_logs,
                args=(name, process),
                daemon=True
            ).start()
            
            return True
            
        except Exception as e:
            self.log(f"❌ Failed to start {name}: {e}", name)
            return False
    
    def _monitor_logs(self, name, process):
        """Monitor service logs"""
        try:
            for line in iter(process.stdout.readline, ''):
                if line.strip():
                    self.log(line.strip(), name)
        except:
            pass
    
    def check_service_health(self, name, check_func):
        """Check if service is healthy"""
        try:
            if name not in self.processes:
                return False
                
            process = self.processes[name]['process']
            
            # Check if process is still running
            if process.poll() is not None:
                return False
                
            # Run custom health check
            return check_func()
            
        except:
            return False
    
    def check_xpc_server(self):
        """Check XPC server health"""
        try:
            response = requests.get("http://localhost:5002/health", timeout=2)
            return response.status_code == 200
        except:
            return False
            
    def check_glass_http_server(self):
        """Check Glass UI HTTP server health"""
        try:
            response = requests.get("http://localhost:5003/health", timeout=2)
            return response.status_code == 200
        except:
            return False
    
    def check_vision_service(self):
        """Check vision service health (basic process check)"""
        return True  # If process is running, assume healthy
    
    def check_glass_ui(self):
        """Check Glass UI health"""
        try:
            # Check if Glass UI process exists
            result = subprocess.run(
                ["pgrep", "-f", "ZeusVLAGlass"],
                capture_output=True,
                timeout=2
            )
            return result.returncode == 0
        except:
            return False
    
    def start_all_services(self):
        """Start all Zeus VLA services"""
        self.log("🎯 Starting Zeus VLA Complete System...")
        
        # 1. Start XPC Memory Server
        success = self.start_service(
            "XPC_SERVER",
            "python3 memory_xpc_server.py --port 5002"
        )
        if not success:
            return False
            
        # Wait for XPC server to start
        self.log("⏳ Waiting for XPC server...")
        time.sleep(3)
        
        # 2. Start Glass UI HTTP Server
        success = self.start_service(
            "GLASS_HTTP",
            "python3 glass_ui_http_server.py"
        )
        if not success:
            return False
            
        # Wait for HTTP server to start
        self.log("⏳ Waiting for Glass UI HTTP server...")
        time.sleep(1)
        
        # 3. Start Continuous Vision Service (with WebSocket integration)
        success = self.start_service(
            "VISION",
            "python3 continuous_vision_service.py"
        )
        if not success:
            return False
            
        # Wait for vision service to initialize
        self.log("⏳ Waiting for vision service...")
        time.sleep(2)
        
        # 3. Build and start Glass UI
        glass_dir = self.base_dir / "GlassUI"
        if glass_dir.exists():
            self.log("🔨 Building Glass UI...")
            build_result = subprocess.run(
                ["swift", "build"],
                cwd=glass_dir,
                capture_output=True,
                text=True
            )
            
            if build_result.returncode == 0:
                success = self.start_service(
                    "GLASS_UI",
                    "./.build/debug/ZeusVLAGlass",
                    cwd=glass_dir
                )
            else:
                self.log(f"❌ Glass UI build failed: {build_result.stderr}", "GLASS_UI")
                return False
        
        self.log("✅ All services started!")
        return True
    
    def monitor_services(self):
        """Monitor all services and restart if needed"""
        self.log("👁️ Starting service monitoring...")
        
        health_checks = {
            "XPC_SERVER": self.check_xpc_server,
            "GLASS_HTTP": self.check_glass_http_server,
            "VISION": self.check_vision_service,
            "GLASS_UI": self.check_glass_ui
        }
        
        while self.running:
            try:
                all_healthy = True
                status_line = "📊 Status: "
                
                for service, check_func in health_checks.items():
                    is_healthy = self.check_service_health(service, check_func)
                    
                    if is_healthy:
                        status_line += f"{service}✅ "
                    else:
                        status_line += f"{service}❌ "
                        all_healthy = False
                        
                        # Try to restart failed service
                        if service in self.processes:
                            self.log(f"🔄 Restarting failed service: {service}", service)
                            self.restart_service(service)
                
                # Print status every 10 seconds
                if int(time.time()) % 10 == 0:
                    self.log(status_line)
                
                time.sleep(1)
                
            except KeyboardInterrupt:
                break
            except Exception as e:
                self.log(f"❌ Monitor error: {e}")
                time.sleep(5)
    
    def restart_service(self, name):
        """Restart a specific service"""
        if name in self.processes:
            proc_info = self.processes[name]
            
            # Kill old process
            try:
                proc_info['process'].terminate()
                proc_info['process'].wait(timeout=5)
            except:
                try:
                    proc_info['process'].kill()
                except:
                    pass
            
            # Restart
            time.sleep(2)
            self.start_service(name, proc_info['command'], proc_info['cwd'])
    
    def show_quick_status(self):
        """Show quick status of all services"""
        self.log("🔍 Quick Status Check...")
        
        # Check XPC Server
        xpc_healthy = self.check_xpc_server()
        self.log(f"XPC Server: {'✅ Running' if xpc_healthy else '❌ Down'}")
        
        # Check Glass UI HTTP Server
        http_healthy = self.check_glass_http_server()
        self.log(f"Glass UI HTTP Server: {'✅ Running' if http_healthy else '❌ Down'}")
        
        # Check Vision Service
        vision_running = subprocess.run(
            ["pgrep", "-f", "continuous_vision_service.py"],
            capture_output=True
        ).returncode == 0
        self.log(f"Vision Service: {'✅ Running' if vision_running else '❌ Down'}")
        
        # Check Glass UI
        glass_running = self.check_glass_ui()
        self.log(f"Glass UI: {'✅ Running' if glass_running else '❌ Down'}")
        
        return xpc_healthy and http_healthy and vision_running and glass_running
    
    def stop_all_services(self):
        """Stop all services"""
        self.log("🛑 Stopping all services...")
        self.running = False
        
        for name, proc_info in self.processes.items():
            try:
                self.log(f"Stopping {name}...", name)
                proc_info['process'].terminate()
                proc_info['process'].wait(timeout=5)
            except:
                try:
                    proc_info['process'].kill()
                except:
                    pass
        
        # Kill any remaining processes
        for proc_name in ["continuous_vision_service.py", "memory_xpc_server.py", "ZeusVLAGlass"]:
            try:
                subprocess.run(["pkill", "-f", proc_name], timeout=2)
            except:
                pass
        
        self.log("✅ All services stopped")

def signal_handler(signum, frame):
    """Handle Ctrl+C"""
    print("\n🛑 Received interrupt signal...")
    launcher.stop_all_services()
    sys.exit(0)

if __name__ == "__main__":
    launcher = ZeusLauncher()
    
    # Setup signal handler
    signal.signal(signal.SIGINT, signal_handler)
    
    if len(sys.argv) > 1:
        command = sys.argv[1]
        
        if command == "status":
            launcher.show_quick_status()
            
        elif command == "stop":
            launcher.stop_all_services()
            
        elif command == "restart":
            launcher.stop_all_services()
            time.sleep(2)
            if launcher.start_all_services():
                launcher.monitor_services()
            
        else:
            print("Usage: python zeus_launcher.py [start|status|stop|restart]")
            print("  start   - Start all services and monitor (default)")
            print("  status  - Show quick status check")
            print("  stop    - Stop all services")
            print("  restart - Restart all services")
    else:
        # Default: start all services and monitor
        if launcher.start_all_services():
            launcher.monitor_services()
        else:
            launcher.log("❌ Failed to start services")
            sys.exit(1)