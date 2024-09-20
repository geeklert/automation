import os
import subprocess

def execute_script():
    if os.name == 'nt':  # For Windows
        script_path = '\scripts\HOTS-Windows-v3-withAWSCLI.ps1'
        command = ["powershell.exe", "-File", script_path]
    else:  # For Linux/Unix
        script_path = '\scripts\HOTS-linux-v3-with-AWSCLI.sh'
        command = ["bash", script_path]
    
    try:
        subprocess.run(command, check=True)
        print(f"Successfully executed {script_path}")
    except subprocess.CalledProcessError as e:
        print(f"Error occurred while executing {script_path}: {e}")

if __name__ == "__main__":
    execute_script()
