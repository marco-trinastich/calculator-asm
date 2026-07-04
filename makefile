# Set the path to vcvarsall.bat or autodiscover if not provided
VCVARSALL_PATH ?=

# Path to vsexec.bat script
VSEXEC_PATH = scripts\components\vsexec.bat

# Build rules
calculator: calculator.obj
	$(if $(VCVARSALL_PATH),set "VCVARSALL_PATH=$(VCVARSALL_PATH)" &&) "$(VSEXEC_PATH)" link /DEBUG /OUT:out\calculator.exe out\calculator.obj

calculator.obj: src\calculator.asm
	if not exist out mkdir out
	nasm -f win64 src\calculator.asm -I src\ -o out\calculator.obj -g

.PHONY: clean
clean:
	if exist out rmdir /s /q out