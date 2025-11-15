#!/bin/bash

# WSL2 Disk Compaction Helper Script
# This script helps you compact the WSL2 virtual disk from Windows
# Note: The actual compaction must be done from Windows PowerShell

echo "⚠️  WSL2 Disk Compaction"
echo "========================"
echo ""
echo "The WSL2 virtual disk doesn't automatically shrink when you delete files."
echo "To reclaim space, you need to compact it from Windows PowerShell."
echo ""
echo "Steps:"
echo "1. Exit this WSL session"
echo "2. Open Windows PowerShell (as Administrator)"
echo "3. Run: wsl --shutdown"
echo "4. Run the PowerShell script: ./scripts/compact-wsl-disk.ps1"
echo ""
echo "Or manually:"
echo "1. wsl --shutdown"
echo "2. Find your VHDX file (usually in %LOCALAPPDATA%\\Packages\\CanonicalGroupLimited.Ubuntu*\\LocalState\\ext4.vhdx)"
echo "3. Use diskpart or Optimize-VHD to compact it"
echo ""
echo "Quick check - Current WSL disk usage:"
df -h / | grep -E "Filesystem|/dev/"

echo ""
echo "Current Docker usage:"
docker system df 2>/dev/null || echo "Docker not running"

