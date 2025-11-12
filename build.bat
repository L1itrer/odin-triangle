@echo off
if not exist .\build mkdir build
odin build src -out:.\build\odingl.exe -debug -subsystem:console
