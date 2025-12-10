#!/bin/bash

# =========================================
# UnixNodes VPS Manager - Complete Auto-Setup
# Version 2.0 | 24/7 Ready | Docker-Ready
# =========================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Banner
echo -e "${PURPLE}"
echo "========================================="
echo "    ⭐ UnixNodes VPS Manager Setup       "
echo "     Complete Auto-Setup Script          "
echo "=========================================${NC}"
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}❌ This script must be run as root/sudo${NC}"
    exit 1
fi

# Function to print status
print_status() {
    echo -e "${BLUE}[*]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

# Detect OS
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        VERSION=$VERSION_ID
    else
        print_error "Cannot detect OS"
        exit 1
    fi
}

# Update system
update_system() {
    print_status "Updating system packages..."
    apt update && apt upgrade -y
    apt install -y curl wget git software-properties-common
    print_success "System updated"
}

# Install LXC/LXD
install_lxc() {
    print_status "Installing LXC/LXD..."
    
    # Remove existing LXD if installed via apt
    apt remove --purge -y lxd lxd-client lxc lxcfs 2>/dev/null || true
    
    # Install snapd
    apt install -y snapd
    systemctl enable --now snapd.socket
    sleep 3
    export PATH=$PATH:/snap/bin
    
    # Install LXD via snap
    snap install lxd --channel=latest/stable
    snap refresh lxd --channel=latest/stable
    
    # Initialize LXD with minimal prompts
    cat <<EOF | lxd init --preseed
config:
  core.https_address: '[::]:8443'
  core.trust_password: unixnodes@secure
  images.auto_update_interval: 6
storage_pools:
- name: default
  driver: dir
  config:
    source: /var/snap/lxd/common/lxd/storage-pools/default
profiles:
- name: default
  config:
    security.nesting: "true"
    security.privileged: "true"
  description: Default UnixNodes profile
  devices:
    root:
      path: /
      pool: default
      type: disk
cluster: null
EOF
    
    # Install LXC tools
    apt install -y lxc lxc-utils lxcfs bridge-utils uidmap dnsmasq-base
    
    # Add user to lxd group
    if [ -n "$SUDO_USER" ]; then
        usermod -aG lxd $SUDO_USER
    fi
    
    print_success "LXC/LXD installed and configured"
}

# Install Python and dependencies
install_python() {
    print_status "Installing Python and dependencies..."
    
    apt install -y python3 python3-pip python3-venv sqlite3
    
    # Create virtual environment
    python3 -m venv /opt/unixnodes/venv
    source /opt/unixnodes/venv/bin/activate
    
    # Install Python packages
    pip3 install discord.py==2.3.2 PyNaCl==1.5.0 python-dotenv psutil
    
    print_success "Python environment configured"
}

# Create directory structure
create_directories() {
    print_status "Creating directory structure..."
    
    mkdir -p /opt/unixnodes/{backups,logs,templates}
    mkdir -p /var/log/unixnodes
    
    # Create bot directory
    rm -rf /opt/unixnodes-bot
    ln -sf /opt/unixnodes /opt/unixnodes-bot
    cd /opt/unixnodes
    
    print_success "Directories created"
}

# Create SQLite database
create_database() {
    print_status "Setting up database..."
    
    sqlite3 /opt/unixnodes/vps.db <<'EOF'
CREATE TABLE IF NOT EXISTS admins (
    user_id TEXT PRIMARY KEY
);

CREATE TABLE IF NOT EXISTS vps (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id TEXT NOT NULL,
    container_name TEXT UNIQUE NOT NULL,
    ram TEXT NOT NULL,
    cpu TEXT NOT NULL,
    storage TEXT NOT NULL,
    config TEXT NOT NULL,
    os_version TEXT DEFAULT 'ubuntu:22.04',
    status TEXT DEFAULT 'stopped',
    suspended INTEGER DEFAULT 0,
    whitelisted INTEGER DEFAULT 0,
    created_at TEXT NOT NULL,
    shared_with TEXT DEFAULT '[]',
    suspension_history TEXT DEFAULT '[]'
);

CREATE TABLE IF NOT EXISTS settings (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL
);

INSERT OR IGNORE INTO settings (key, value) VALUES 
    ('cpu_threshold', '90'),
    ('ram_threshold', '90'),
    ('auto_suspend', '1'),
    ('backup_days', '7'),
    ('max_vps_per_user', '5');

CREATE TABLE IF NOT EXISTS logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp TEXT NOT NULL,
    level TEXT NOT NULL,
    message TEXT NOT NULL,
    user_id TEXT,
    container_name TEXT
);

CREATE INDEX IF NOT EXISTS idx_vps_user ON vps(user_id);
CREATE INDEX IF NOT EXISTS idx_vps_container ON vps(container_name);
CREATE INDEX IF NOT EXISTS idx_logs_timestamp ON logs(timestamp);
EOF
    
    chmod 644 /opt/unixnodes/vps.db
    print_success "Database created"
}

# Create bot.py
create_bot_py() {
    print_status "Creating bot.py..."
    
    cat > /opt/unixnodes/bot.py <<'EOF'
#!/usr/bin/env python3
"""
⭐ UnixNodes VPS Manager Bot
Complete LXC/LXD Management System
24/7 Operation with Auto-Scaling
"""

import discord
from discord.ext import commands
import asyncio
import subprocess
import json
from datetime import datetime
import shlex
import logging
import shutil
import os
import sys
import sqlite3
import time
import threading
import psutil
from typing import Optional, List, Dict, Any
from dotenv import load_dotenv

# Load environment
load_dotenv('/opt/unixnodes/.env')

# Configuration
DISCORD_TOKEN = os.getenv('DISCORD_TOKEN', '')
MAIN_ADMIN_ID = int(os.getenv('MAIN_ADMIN_ID', '0'))
VPS_USER_ROLE_ID = int(os.getenv('VPS_USER_ROLE_ID', '0'))
DEFAULT_STORAGE_POOL = os.getenv('DEFAULT_STORAGE_POOL', 'default')
BOT_PREFIX = os.getenv('BOT_PREFIX', '!')

# OS Options
OS_OPTIONS = [
    {"label": "Ubuntu 20.04 LTS", "value": "ubuntu:20.04"},
    {"label": "Ubuntu 22.04 LTS", "value": "ubuntu:22.04"},
    {"label": "Ubuntu 24.04 LTS", "value": "ubuntu:24.04"},
    {"label": "Debian 11 (Bullseye)", "value": "images:debian/11"},
    {"label": "Debian 12 (Bookworm)", "value": "images:debian/12"},
    {"label": "Alpine Linux", "value": "alpine/edge"},
]

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/var/log/unixnodes/bot.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger('UnixNodesBot')

# Check LXC
if not shutil.which("lxc"):
    logger.error("LXC not found. Install with: snap install lxd")
    sys.exit(1)

# Database functions
def get_db():
    conn = sqlite3.connect('/opt/unixnodes/vps.db')
    conn.row_factory = sqlite3.Row
    return conn

def init_db():
    conn = get_db()
    c = conn.cursor()
    
    # Ensure tables exist
    c.execute('''CREATE TABLE IF NOT EXISTS admins (user_id TEXT PRIMARY KEY)''')
    c.execute('''CREATE TABLE IF NOT EXISTS vps (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        container_name TEXT UNIQUE NOT NULL,
        ram TEXT NOT NULL,
        cpu TEXT NOT NULL,
        storage TEXT NOT NULL,
        config TEXT NOT NULL,
        os_version TEXT DEFAULT 'ubuntu:22.04',
        status TEXT DEFAULT 'stopped',
        suspended INTEGER DEFAULT 0,
        whitelisted INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        shared_with TEXT DEFAULT '[]',
        suspension_history TEXT DEFAULT '[]'
    )''')
    
    c.execute('''CREATE TABLE IF NOT EXISTS settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
    )''')
    
    c.execute('''CREATE TABLE IF NOT EXISTS logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        timestamp TEXT NOT NULL,
        level TEXT NOT NULL,
        message TEXT NOT NULL,
        user_id TEXT,
        container_name TEXT
    )''')
    
    # Default settings
    default_settings = [
        ('cpu_threshold', '90'),
        ('ram_threshold', '90'),
        ('auto_suspend', '1'),
        ('backup_days', '7'),
        ('max_vps_per_user', '5'),
    ]
    
    for key, value in default_settings:
        c.execute('INSERT OR IGNORE INTO settings (key, value) VALUES (?, ?)', (key, value))
    
    # Insert main admin
    if MAIN_ADMIN_ID:
        c.execute('INSERT OR IGNORE INTO admins (user_id) VALUES (?)', (str(MAIN_ADMIN_ID),))
    
    conn.commit()
    conn.close()

def log_event(level: str, message: str, user_id: str = None, container: str = None):
    conn = get_db()
    c = conn.cursor()
    c.execute('INSERT INTO logs (timestamp, level, message, user_id, container_name) VALUES (?, ?, ?, ?, ?)',
              (datetime.now().isoformat(), level, message, user_id, container))
    conn.commit()
    conn.close()
    logger.log(getattr(logging, level.upper(), logging.INFO), message)

# Initialize database
init_db()

# Load data
def load_vps_data():
    conn = get_db()
    c = conn.cursor()
    c.execute('SELECT * FROM vps')
    rows = c.fetchall()
    data = {}
    for row in rows:
        user_id = row['user_id']
        if user_id not in data:
            data[user_id] = []
        vps = dict(row)
        vps['shared_with'] = json.loads(vps['shared_with'])
        vps['suspension_history'] = json.loads(vps['suspension_history'])
        data[user_id].append(vps)
    conn.close()
    return data

def load_admins():
    conn = get_db()
    c = conn.cursor()
    c.execute('SELECT user_id FROM admins')
    admins = [row['user_id'] for row in c.fetchall()]
    conn.close()
    return admins

vps_data = load_vps_data()
admin_list = load_admins()

# Helper: Execute LXC command
async def lxc_exec(command: str, timeout: int = 60):
    try:
        proc = await asyncio.create_subprocess_exec(
            *shlex.split(f"lxc {command}"),
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE
        )
        stdout, stderr = await asyncio.wait_for(proc.communicate(), timeout=timeout)
        
        if proc.returncode != 0:
            error = stderr.decode().strip() if stderr else "Unknown error"
            raise Exception(f"LXC Error: {error}")
        
        return stdout.decode().strip() if stdout else ""
    except asyncio.TimeoutError:
        proc.kill()
        raise Exception(f"Command timeout: {command}")
    except Exception as e:
        raise Exception(f"Execution failed: {str(e)}")

# Helper: Create embed
def create_embed(title: str, description: str = "", color: int = 0x1a1a1a):
    embed = discord.Embed(
        title=f"⭐ UnixNodes - {title}",
        description=description[:4096],
        color=color,
        timestamp=datetime.now()
    )
    embed.set_footer(text="UnixNodes VPS Manager | 24/7 Hosting")
    return embed

# Bot setup
intents = discord.Intents.default()
intents.message_content = True
intents.members = True
bot = commands.Bot(command_prefix=BOT_PREFIX, intents=intents, help_command=None)

# Events
@bot.event
async def on_ready():
    logger.info(f"{bot.user} is online!")
    await bot.change_presence(activity=discord.Activity(
        type=discord.ActivityType.watching,
        name="UnixNodes VPS Manager"
    ))
    log_event("INFO", f"Bot started as {bot.user}")

@bot.event
async def on_command_error(ctx, error):
    if isinstance(error, commands.CommandNotFound):
        return
    logger.error(f"Command error: {error}")
    embed = create_embed("Error", str(error)[:2000], 0xff0000)
    await ctx.send(embed=embed)

# Commands
@bot.command(name='ping')
async def ping_cmd(ctx):
    """Check bot latency"""
    latency = round(bot.latency * 1000)
    embed = create_embed("Pong! 🏓", f"Latency: {latency}ms", 0x00ff00)
    await ctx.send(embed=embed)

@bot.command(name='status')
async def status_cmd(ctx):
    """System status"""
    cpu = psutil.cpu_percent()
    mem = psutil.virtual_memory().percent
    disk = psutil.disk_usage('/').percent
    
    embed = create_embed("System Status", "Current resource usage:", 0x0099ff)
    embed.add_field(name="CPU", value=f"{cpu}%", inline=True)
    embed.add_field(name="RAM", value=f"{mem}%", inline=True)
    embed.add_field(name="Disk", value=f"{disk}%", inline=True)
    embed.add_field(name="Uptime", value=str(datetime.now() - psutil.boot_time()), inline=False)
    await ctx.send(embed=embed)

@bot.command(name='create')
@commands.has_role('Admin')
async def create_cmd(ctx, ram: int, cpu: int, disk: int, member: discord.Member):
    """Create new VPS [Admin only]"""
    if ram < 1 or cpu < 1 or disk < 1:
        await ctx.send(embed=create_embed("Error", "Values must be positive!", 0xff0000))
        return
    
    embed = create_embed("Create VPS", f"Creating for {member.mention}\nRAM: {ram}GB | CPU: {cpu} | Disk: {disk}GB", 0x0099ff)
    view = OSSelectView(ram, cpu, disk, member, ctx)
    await ctx.send(embed=embed, view=view)

class OSSelectView(discord.ui.View):
    def __init__(self, ram, cpu, disk, member, ctx):
        super().__init__(timeout=60)
        self.ram = ram
        self.cpu = cpu
        self.disk = disk
        self.member = member
        self.ctx = ctx
        
        options = []
        for os_opt in OS_OPTIONS[:5]:  # First 5 options
            options.append(discord.SelectOption(
                label=os_opt['label'],
                value=os_opt['value']
            ))
        
        self.select = discord.ui.Select(
            placeholder="Select OS...",
            options=options
        )
        self.select.callback = self.select_callback
        self.add_item(self.select)
    
    async def select_callback(self, interaction: discord.Interaction):
        if interaction.user.id != self.ctx.author.id:
            await interaction.response.send_message("Not your command!", ephemeral=True)
            return
        
        os_image = self.select.values[0]
        await interaction.response.defer()
        
        try:
            # Create container
            container_name = f"unixnodes-{self.member.id}-{int(time.time())}"
            await lxc_exec(f"init {os_image} {container_name}")
            await lxc_exec(f"config set {container_name} limits.memory {self.ram}GB")
            await lxc_exec(f"config set {container_name} limits.cpu {self.cpu}")
            await lxc_exec(f"config device set {container_name} root size={self.disk}GB")
            
            # Enable features
            await lxc_exec(f"config set {container_name} security.nesting true")
            await lxc_exec(f"config set {container_name} security.privileged true")
            
            # Start container
            await lxc_exec(f"start {container_name}")
            
            # Save to database
            conn = get_db()
            c = conn.cursor()
            c.execute('''INSERT INTO vps 
                (user_id, container_name, ram, cpu, storage, config, os_version, status, created_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)''',
                (
                    str(self.member.id),
                    container_name,
                    f"{self.ram}GB",
                    str(self.cpu),
                    f"{self.disk}GB",
                    f"{self.ram}GB/{self.cpu}CPU/{self.disk}GB",
                    os_image,
                    "running",
                    datetime.now().isoformat()
                ))
            conn.commit()
            conn.close()
            
            # Update local data
            if str(self.member.id) not in vps_data:
                vps_data[str(self.member.id)] = []
            vps_data[str(self.member.id)].append({
                'container_name': container_name,
                'ram': f"{self.ram}GB",
                'cpu': str(self.cpu),
                'storage': f"{self.disk}GB",
                'status': 'running'
            })
            
            embed = create_embed("VPS Created! 🎉", 
                f"**User:** {self.member.mention}\n"
                f"**Container:** `{container_name}`\n"
                f"**OS:** {os_image}\n"
                f"**Specs:** {self.ram}GB RAM, {self.cpu} CPU, {self.disk}GB Disk\n"
                f"**Status:** Running", 0x00ff00)
            
            await interaction.followup.send(embed=embed)
            
            # DM user
            try:
                user_embed = create_embed("Your VPS is Ready!",
                    f"Your UnixNodes VPS has been created.\n"
                    f"**Name:** {container_name}\n"
                    f"**Specs:** {self.ram}GB RAM / {self.cpu} CPU / {self.disk}GB Disk\n"
                    f"**OS:** {os_image}\n\n"
                    f"Use `{BOT_PREFIX}manage` to control your VPS.", 0x00ff00)
                await self.member.send(embed=user_embed)
            except:
                pass
                
        except Exception as e:
            embed = create_embed("Creation Failed", str(e), 0xff0000)
            await interaction.followup.send(embed=embed)

@bot.command(name='manage')
async def manage_cmd(ctx, member: discord.Member = None):
    """Manage your VPS"""
    target = member or ctx.author
    user_id = str(target.id)
    
    if user_id not in vps_data or not vps_data[user_id]:
        embed = create_embed("No VPS Found", "You don't have any VPS.", 0xffaa00)
        await ctx.send(embed=embed)
        return
    
    vps_list = vps_data[user_id]
    embed = create_embed(f"{target.name}'s VPS", f"Total: {len(vps_list)}", 0x0099ff)
    
    for i, vps in enumerate(vps_list, 1):
        status = "🟢" if vps['status'] == 'running' else "🔴"
        embed.add_field(
            name=f"VPS #{i} {status}",
            value=f"**Name:** `{vps['container_name']}`\n"
                  f"**Specs:** {vps['ram']} / {vps['cpu']} CPU / {vps['storage']}\n"
                  f"**Status:** {vps['status'].title()}",
            inline=False
        )
    
    embed.add_field(name="Commands", 
        value=f"`{BOT_PREFIX}start <name>` - Start VPS\n"
              f"`{BOT_PREFIX}stop <name>` - Stop VPS\n"
              f"`{BOT_PREFIX}ssh <name>` - Get SSH access\n"
              f"`{BOT_PREFIX}delete <name>` - Delete VPS", inline=False)
    
    await ctx.send(embed=embed)

@bot.command(name='start')
async def start_cmd(ctx, container_name: str):
    """Start a VPS"""
    user_id = str(ctx.author.id)
    
    # Find VPS
    vps = None
    for user_vps in vps_data.get(user_id, []):
        if user_vps['container_name'] == container_name:
            vps = user_vps
            break
    
    if not vps:
        await ctx.send(embed=create_embed("Error", "VPS not found or not yours.", 0xff0000))
        return
    
    try:
        await lxc_exec(f"start {container_name}")
        vps['status'] = 'running'
        
        # Update DB
        conn = get_db()
        c = conn.cursor()
        c.execute("UPDATE vps SET status = ? WHERE container_name = ?", 
                 ('running', container_name))
        conn.commit()
        conn.close()
        
        embed = create_embed("VPS Started", f"`{container_name}` is now running.", 0x00ff00)
        await ctx.send(embed=embed)
    except Exception as e:
        await ctx.send(embed=create_embed("Error", str(e), 0xff0000))

@bot.command(name='stop')
async def stop_cmd(ctx, container_name: str):
    """Stop a VPS"""
    user_id = str(ctx.author.id)
    
    # Find VPS
    vps = None
    for user_vps in vps_data.get(user_id, []):
        if user_vps['container_name'] == container_name:
            vps = user_vps
            break
    
    if not vps:
        await ctx.send(embed=create_embed("Error", "VPS not found or not yours.", 0xff0000))
        return
    
    try:
        await lxc_exec(f"stop {container_name}")
        vps['status'] = 'stopped'
        
        # Update DB
        conn = get_db()
        c = conn.cursor()
        c.execute("UPDATE vps SET status = ? WHERE container_name = ?", 
                 ('stopped', container_name))
        conn.commit()
        conn.close()
        
        embed = create_embed("VPS Stopped", f"`{container_name}` has been stopped.", 0xffaa00)
        await ctx.send(embed=embed)
    except Exception as e:
        await ctx.send(embed=create_embed("Error", str(e), 0xff0000))

@bot.command(name='ssh')
async def ssh_cmd(ctx, container_name: str):
    """Get SSH access to VPS"""
    user_id = str(ctx.author.id)
    
    # Find VPS
    vps = None
    for user_vps in vps_data.get(user_id, []):
        if user_vps['container_name'] == container_name:
            vps = user_vps
            break
    
    if not vps or vps['status'] != 'running':
        await ctx.send(embed=create_embed("Error", "VPS not found or not running.", 0xff0000))
        return
    
    try:
        # Install tmate if not present
        await lxc_exec(f"exec {container_name} -- bash -c 'which tmate || apt update && apt install -y tmate'")
        
        # Generate SSH session
        session_id = f"unixnodes-{int(time.time())}"
        await lxc_exec(f"exec {container_name} -- tmate -S /tmp/tmate.sock new-session -d")
        await asyncio.sleep(2)
        
        result = await lxc_exec(f"exec {container_name} -- tmate -S /tmp/tmate.sock display -p '#{{tmate_ssh}}'")
        
        if result:
            embed = create_embed("SSH Access", f"**Container:** `{container_name}`", 0x0099ff)
            embed.add_field(name="SSH Command", value=f"```{result}```", inline=False)
            embed.add_field(name="Note", value="This session expires. Keep it secure.", inline=False)
            
            try:
                await ctx.author.send(embed=embed)
                await ctx.send(embed=create_embed("Check DMs!", "SSH details sent to your DMs.", 0x00ff00))
            except:
                await ctx.send(embed=embed)
        else:
            await ctx.send(embed=create_embed("Error", "Failed to generate SSH session.", 0xff0000))
    except Exception as e:
        await ctx.send(embed=create_embed("Error", str(e), 0xff0000))

@bot.command(name='list')
@commands.has_role('Admin')
async def list_cmd(ctx):
    """List all VPS [Admin only]"""
    if not vps_data:
        await ctx.send(embed=create_embed("No VPS", "No VPS containers found.", 0xffaa00))
        return
    
    embed = create_embed("All VPS Containers", f"Total: {sum(len(v) for v in vps_data.values())}", 0x0099ff)
    
    for user_id, containers in vps_data.items():
        try:
            user = await bot.fetch_user(int(user_id))
            username = user.name
        except:
            username = f"User {user_id}"
        
        for vps in containers:
            status = "🟢" if vps['status'] == 'running' else "🔴"
            embed.add_field(
                name=f"{status} {vps['container_name']}",
                value=f"**User:** {username}\n**Specs:** {vps['ram']} / {vps['cpu']} CPU",
                inline=True
            )
    
    await ctx.send(embed=embed)

@bot.command(name='stats')
async def stats_cmd(ctx, container_name: str = None):
    """Get VPS statistics"""
    if container_name:
        # Specific container
        try:
            info = await lxc_exec(f"info {container_name}")
            status = "Running" if "Status: Running" in info else "Stopped"
            
            embed = create_embed(f"Stats: {container_name}", f"**Status:** {status}", 0x0099ff)
            
            # Parse info
            for line in info.split('\n'):
                if 'Memory usage:' in line:
                    embed.add_field(name="Memory", value=line.split(':', 1)[1].strip(), inline=True)
                elif 'CPU usage:' in line:
                    embed.add_field(name="CPU", value=line.split(':', 1)[1].strip(), inline=True)
                elif 'Disk usage:' in line:
                    embed.add_field(name="Disk", value=line.split(':', 1)[1].strip(), inline=True)
            
            await ctx.send(embed=embed)
        except Exception as e:
            await ctx.send(embed=create_embed("Error", str(e), 0xff0000))
    else:
        # Global stats
        total = sum(len(v) for v in vps_data.values())
        running = sum(1 for v in vps_data.values() for vps in v if vps['status'] == 'running')
        
        embed = create_embed("Global Statistics", "", 0x0099ff)
        embed.add_field(name="Total VPS", value=str(total), inline=True)
        embed.add_field(name="Running", value=str(running), inline=True)
        embed.add_field(name="Stopped", value=str(total - running), inline=True)
        embed.add_field(name="Total Users", value=str(len(vps_data)), inline=True)
        
        await ctx.send(embed=embed)

@bot.command(name='help')
async def help_cmd(ctx):
    """Show help"""
    embed = create_embed("UnixNodes VPS Manager", "Complete VPS Management System", 0x0099ff)
    
    # User commands
    embed.add_field(name="👤 User Commands", 
        value=f"`{BOT_PREFIX}ping` - Check bot latency\n"
              f"`{BOT_PREFIX}manage` - List your VPS\n"
              f"`{BOT_PREFIX}start <name>` - Start VPS\n"
              f"`{BOT_PREFIX}stop <name>` - Stop VPS\n"
              f"`{BOT_PREFIX}ssh <name>` - SSH access\n"
              f"`{BOT_PREFIX}stats [name]` - VPS statistics", inline=False)
    
    # Admin commands
    if any(role.name == 'Admin' for role in ctx.author.roles) or str(ctx.author.id) in admin_list:
        embed.add_field(name="🛡️ Admin Commands",
            value=f"`{BOT_PREFIX}create <ram> <cpu> <disk> @user` - Create VPS\n"
                  f"`{BOT_PREFIX}list` - List all VPS\n"
                  f"`{BOT_PREFIX}exec <name> <command>` - Execute command\n"
                  f"`{BOT_PREFIX}delete <name>` - Delete VPS", inline=False)
    
    embed.add_field(name="📊 System", 
        value=f"`{BOT_PREFIX}status` - System status\n"
              f"`{BOT_PREFIX}help` - This menu", inline=False)
    
    embed.set_footer(text=f"Prefix: {BOT_PREFIX} | Need help? Contact admin")
    await ctx.send(embed=embed)

# Resource Monitor Thread
class ResourceMonitor(threading.Thread):
    def __init__(self, bot_instance):
        super().__init__(daemon=True)
        self.bot = bot_instance
        self.running = True
    
    def run(self):
        while self.running:
            try:
                # Check system resources
                cpu = psutil.cpu_percent()
                mem = psutil.virtual_memory().percent
                
                if cpu > 90 or mem > 90:
                    logger.warning(f"High resource usage: CPU {cpu}%, RAM {mem}%")
                
                # Sleep for 60 seconds
                time.sleep(60)
            except Exception as e:
                logger.error(f"Monitor error: {e}")
                time.sleep(60)
    
    def stop(self):
        self.running = False

# Start monitor
monitor = ResourceMonitor(bot)
monitor.start()

# Run bot
if __name__ == "__main__":
    if not DISCORD_TOKEN:
        logger.error("No DISCORD_TOKEN in environment!")
        sys.exit(1)
    
    try:
        bot.run(DISCORD_TOKEN)
    except KeyboardInterrupt:
        logger.info("Shutting down...")
        monitor.stop()
        monitor.join()
    except Exception as e:
        logger.error(f"Bot crashed: {e}")
        sys.exit(1)
EOF
    
    chmod +x /opt/unixnodes/bot.py
    print_success "bot.py created"
}

# Create environment file
create_env_file() {
    print_status "Creating environment configuration..."
    
    cat > /opt/unixnodes/.env <<'EOF'
# UnixNodes VPS Manager Configuration
# ===================================

# Discord Bot Settings
DISCORD_TOKEN=YOUR_BOT_TOKEN_HERE
MAIN_ADMIN_ID=YOUR_DISCORD_ID_HERE
VPS_USER_ROLE_ID=YOUR_VPS_ROLE_ID_HERE
BOT_PREFIX=!

# LXC/LXD Settings
DEFAULT_STORAGE_POOL=default
LXD_SNAPSHOT_RETENTION=7

# Resource Limits
MAX_VPS_PER_USER=5
DEFAULT_RAM=2
DEFAULT_CPU=1
DEFAULT_DISK=20

# Monitoring
CPU_THRESHOLD=90
RAM_THRESHOLD=90
CHECK_INTERVAL=60

# Security
ALLOW_SSH=true
AUTO_SUSPEND=true
BACKUP_ENABLED=true

# Logging
LOG_LEVEL=INFO
LOG_RETENTION_DAYS=30
EOF
    
    print_success ".env file created"
}

# Create systemd service
create_service() {
    print_status "Creating systemd service..."
    
    cat > /etc/systemd/system/unixnodes-bot.service <<'EOF'
[Unit]
Description=UnixNodes VPS Manager Bot
After=network.target snap.lxd.daemon.service
Wants=snap.lxd.daemon.service

[Service]
Type=simple
User=root
WorkingDirectory=/opt/unixnodes
Environment="PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin"
EnvironmentFile=/opt/unixnodes/.env
ExecStart=/opt/unixnodes/venv/bin/python3 /opt/unixnodes/bot.py
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=unixnodes-bot

# Security
ProtectSystem=strict
ReadWritePaths=/opt/unixnodes /var/log/unixnodes
PrivateTmp=true
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
EOF
    
    # Create logrotate config
    cat > /etc/logrotate.d/unixnodes <<'EOF'
/var/log/unixnodes/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 640 root adm
    sharedscripts
    postrotate
        systemctl reload unixnodes-bot > /dev/null 2>&1 || true
    endscript
}
EOF
    
    systemctl daemon-reload
    print_success "Systemd service created"
}

# Create maintenance scripts
create_maintenance_scripts() {
    print_status "Creating maintenance scripts..."
    
    # Backup script
    cat > /opt/unixnodes/backup.sh <<'EOF'
#!/bin/bash
# UnixNodes Backup Script
BACKUP_DIR="/opt/unixnodes/backups"
DATE=$(date +%Y%m%d_%H%M%S)
mkdir -p $BACKUP_DIR

echo "[$(date)] Starting backup..." >> /var/log/unixnodes/backup.log

# Backup database
cp /opt/unixnodes/vps.db $BACKUP_DIR/vps_$DATE.db

# Backup .env (without token)
grep -v "TOKEN" /opt/unixnodes/.env > $BACKUP_DIR/env_$DATE.backup 2>/dev/null || true

# Backup LXC containers
lxc list --format json > $BACKUP_DIR/lxc_list_$DATE.json

# Clean old backups (keep 7 days)
find $BACKUP_DIR -name "*.db" -mtime +7 -delete
find $BACKUP_DIR -name "*.backup" -mtime +7 -delete
find $BACKUP_DIR -name "*.json" -mtime +7 -delete

echo "[$(date)] Backup completed: $BACKUP_DIR/vps_$DATE.db" >> /var/log/unixnodes/backup.log
EOF
    
    # Update script
    cat > /opt/unixnodes/update.sh <<'EOF'
#!/bin/bash
# UnixNodes Update Script
echo "[$(date)] Starting update..." >> /var/log/unixnodes/update.log

# Stop bot
systemctl stop unixnodes-bot

# Update system
apt update && apt upgrade -y

# Update Python packages
cd /opt/unixnodes
source venv/bin/activate
pip install --upgrade discord.py PyNaCl python-dotenv psutil

# Restart bot
systemctl start unixnodes-bot

echo "[$(date)] Update completed" >> /var/log/unixnodes/update.log
echo "Update completed!"
EOF
    
    # Monitor script
    cat > /opt/unixnodes/monitor.sh <<'EOF'
#!/bin/bash
# UnixNodes Monitor Script
LOG="/var/log/unixnodes/monitor.log"
DATE=$(date '+%Y-%m-%d %H:%M:%S')

# Check bot service
if ! systemctl is-active --quiet unixnodes-bot; then
    echo "[$DATE] ERROR: Bot service is down! Restarting..." >> $LOG
    systemctl restart unixnodes-bot
    sleep 5
    if systemctl is-active --quiet unixnodes-bot; then
        echo "[$DATE] INFO: Bot restarted successfully" >> $LOG
    else
        echo "[$DATE] CRITICAL: Failed to restart bot!" >> $LOG
    fi
fi

# Check LXD
if ! systemctl is-active --quiet snap.lxd.daemon; then
    echo "[$DATE] ERROR: LXD service is down!" >> $LOG
fi

# Check disk space
DISK=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
if [ $DISK -gt 90 ]; then
    echo "[$DATE] WARNING: Disk usage is ${DISK}%" >> $LOG
fi

# Check memory
MEM=$(free -m | awk 'NR==2{printf "%.1f", $3*100/$2}')
if (( $(echo "$MEM > 90" | bc -l) )); then
    echo "[$DATE] WARNING: Memory usage is ${MEM}%" >> $LOG
fi
EOF
    
    chmod +x /opt/unixnodes/*.sh
    
    # Add to crontab
    (crontab -l 2>/dev/null; echo "0 2 * * * /opt/unixnodes/backup.sh") | crontab -
    (crontab -l 2>/dev/null; echo "*/5 * * * * /opt/unixnodes/monitor.sh") | crontab -
    (crontab -l 2>/dev/null; echo "0 4 * * 0 /opt/unixnodes/update.sh") | crontab -
    
    print_success "Maintenance scripts created"
}

# Create setup completion
create_completion() {
    print_status "Finalizing setup..."
    
    # Set permissions
    chown -R root:root /opt/unixnodes
    chmod 755 /opt/unixnodes
    chmod 644 /opt/unixnodes/.env
    
    # Enable and start service
    systemctl enable unixnodes-bot
    
    # Create info file
    cat > /opt/unixnodes/SETUP_INFO.md <<'EOF'
# UnixNodes VPS Manager Setup Complete!

## Configuration Needed:
1. Edit `/opt/unixnodes/.env` and add:
   - DISCORD_TOKEN (from Discord Developer Portal)
   - MAIN_ADMIN_ID (your Discord user ID)
   - VPS_USER_ROLE_ID (optional VPS user role ID)

2. Start the bot:
   ```bash
   systemctl start unixnodes-bot
   systemctl status unixnodes-bot
