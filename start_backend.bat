@echo off
cd /d "%~dp0backend"
if not exist .env copy .env.example .env
py -3 -m pip install -q -r requirements.txt
py -3 run.py