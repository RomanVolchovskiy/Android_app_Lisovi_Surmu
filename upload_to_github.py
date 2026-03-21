#!/usr/bin/env python3
"""
Upload script for GitHub using the existing GitHub setup
"""

import subprocess
import os
import sys

def run_command(cmd, cwd=None):
    """Run a shell command and return the result"""
    try:
        result = subprocess.run(cmd, shell=True, cwd=cwd, capture_output=True, text=True)
        if result.returncode != 0:
            print(f"Error: {result.stderr}")
            return False
        print(result.stdout)
        return True
    except Exception as e:
        print(f"Command failed: {e}")
        return False

def main():
    project_dir = "/home/user/flutter_app"
    
    print("🚀 Starting GitHub upload process...")
    
    # Change to project directory
    os.chdir(project_dir)
    
    # Check git status
    print("📋 Checking git status...")
    if not run_command("git status"):
        return False
    
    # Add all files
    print("📁 Adding all files...")
    if not run_command("git add ."):
        return False
    
    # Commit if there are changes
    print("💾 Committing changes...")
    result = subprocess.run("git diff --cached --quiet", shell=True)
    if result.returncode != 0:  # There are staged changes
        if not run_command('git commit -m "Update: Hunting Signals Flutter app with Firebase integration and fixed compilation errors"'):
            return False
    else:
        print("No changes to commit")
    
    # Try to push with the existing setup
    print("📤 Pushing to GitHub...")
    
    # Method 1: Try with the existing credential helper
    print("Trying with credential store...")
    result = subprocess.run(
        "git push origin main", 
        shell=True, 
        env={**os.environ, 'GIT_TRACE': '1', 'GIT_CURL_VERBOSE': '1'}
    )
    
    if result.returncode == 0:
        print("✅ Successfully pushed to GitHub!")
        return True
    else:
        print("❌ Push failed, but code is ready. You can manually push from GitHub interface.")
        print("📍 Repository: https://github.com/RomanVolchovskiy/Forest-Hunter-Signals")
        print("🔧 To manually push, go to your repository and drag/drop the flutter_app folder")
        return False

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)