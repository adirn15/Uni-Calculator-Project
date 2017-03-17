#format is target-name: target dependencies
#{-tab-}actions

# All Targets
all: calc

# Tool invocations
# Executable "calc" depends on the files calc.o
calc: calc.o
	gcc -m32 -g -Wall -o calc calc.o

calc.o: calc.s
	nasm -g -f elf -w+all -o calc.o calc.s

#tell make that "clean" is not a file name!
.PHONY: clean

#Clean the build directory
clean: 
	rm -f *.o calc
