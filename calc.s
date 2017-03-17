LINK_SIZE EQU 5 		; 1 byte 2 digits of int, 4 bytes for pointer
DATA EQU 0 				; relative jump to data in link
NEXT EQU 1 				; relative space in struct to next pointer
BUF_SIZE EQU 80

section .bss
	STACK: RESB 20		 ; 5 ints max -> 20 bytes
	STK_PTR: RESB 4 	 ; the ESP for our stack
	INPUT: RESB 80		 ; maximum buffer size for string input (of a number)
	INP_SIZE: RESB 4     ; input size
	OFFSET: RESB 4       ; offset for coverting input to number
	WHILE_FLAG: RESB 1   ; continue while or not
	STACK_SIZE: RESB 4   ; size of stack
	LAST_LINK_PTR: RESB 4
	PRINT_COUNT: RESB 4
	TEMP_LINK: RESB 5 
	INP_LENGTH: RESB 4
	COUNT1: RESB 4
	COUNT2: RESB 4
	TEMP: RESB 4
	CARRY: RESB 1
	OP_NUM: RESB 4
	DEBUG: RESB 1
	COMMAND: RESB 1

section .rodata
	STR_FORMAT: DB "%s",10,0   ; string format for printf
	HEX_FORMAT: DB "%x",0   ; string format for printf
	HEX0_FORMAT: DB "%02x",0   ; string format for printf
	INT_FORMAT: DB "%d",10,0   ; string format for printf

	ASK_FOR_INPUT: DB 10,"calc: ",0
	ILLEGAL_COMMAND: DB 10,"Error: Illegal Input",10,0
	STACK_UNDERFLOW: DB 10,"Error: Insufficient Number of Arguments on Stack",10,0
	STACK_OVERFLOW: DB 10,"Error: Operand Stack Overflow",10,0
	OPS: DB 10,"Number of operations: ",10,0
	RESULT: DB 10,"The result is: ",0
	ADD_NUM: DB 10,"Added number: ",0


section .text

align 16
global main
extern printf
extern fprintf
extern malloc
extern free

main:
	mov byte [COMMAND],-1
	mov byte [DEBUG],0
	pop ecx  			;ecx=ret address
	pop ebx 			;ebx=argc
	pop edx  			;edx=argv
	mov edx,[edx+4]     ;edx=argv[1]
	mov ebx,0
	
	cmp edx,0
	je .cont
	mov bh, [edx] 		;first letter arg1
	mov bl, [edx+1] 	;second letter arg1
    
	cmp bh,45 			;45= "-"
	jne .cont 
	cmp bl,100  		;100= "d"
	jne .cont
	inc byte [DEBUG]

.cont:
	mov dword [STACK_SIZE],0
	inc byte [WHILE_FLAG]
	call my_calc
	
	push OPS
	push STR_FORMAT
	call printf			; print "num of arguments:"
	add esp,8
	push dword [OP_NUM]
	push INT_FORMAT
	call printf 		; print num_ops
	add esp,8

	mov eax,1 			;exit
	int 0x80

;**************************************************************************************************
;***************************************  MY CALC  ************************************************


my_calc:

	push ebp
	mov	ebp, esp	; Entry code - set up ebp and esp	
	pushad			; Save registers
	
	mov dword [OP_NUM],0

_while: 
	mov dword [LAST_LINK_PTR],0	
	cmp byte [WHILE_FLAG],1
	jne end_while
	
	cmp byte [DEBUG],1
	jne .cont

	cmp byte [COMMAND],0 		; read number
	jne .com
	push ADD_NUM
	push STR_FORMAT
	call printf
	add esp,8
	call print_debug

.com:
	cmp byte [COMMAND],1 		; read command
	jne .cont
	push RESULT
	push STR_FORMAT
	call printf
	add esp,8
	call print_debug

.cont:

	ask_input:

		push ASK_FOR_INPUT	         ; arg1: pointer to string
		push STR_FORMAT 	         ; arg2: format
		call printf 
		add esp,8 	 		         ; clean up stack after call
	  
	read_input:
									 ; read input from stdin
		mov eax,3 					 ; "read"
		mov ebx,0 					 ; stdin
		mov ecx, INPUT 		     	 ; buffer to keep data
		mov edx, BUF_SIZE  		     ; how many bytes to read
		int 0x80 					 ; sys-call- eax=num of bytes read

	call_right_func:
		
		mov dword [OFFSET], 0        ; reset offset counter

		cmp eax,1 					 ; if error reading
		jle _while
		mov dword [OFFSET], 0        ; reset offset counter
		cmp eax,2 					 ; if size -> 2 it is a command or a number	
		je check_commands 	
		dec eax
		mov dword [INP_LENGTH],eax
		call add_num_to_stack	
		jmp _while

	check_commands:
		mov byte [COMMAND],-1
		.quit:
			cmp byte [INPUT],113 		;ascii q=113
			jne .pop
			call quit_func
			jmp end_while
		.pop:
			cmp byte [INPUT],112 		;ascii p=112
			jne .dup
			call pop_func
			inc dword [OP_NUM]
			jmp _while
		.dup:
			cmp byte [INPUT],100 		;ascii d=100
			jne .plus
			call dup_func
			inc dword [OP_NUM]
			jmp _while
		.plus:
			cmp byte [INPUT],43 		;ascii + =43
			jne .and
			call add_op
			inc dword [OP_NUM]
			jmp _while
		.and:
			cmp byte [INPUT],38 		;ascii & =38
			jne .number
			call and_op 
			inc dword [OP_NUM]
			jmp _while
		.number:
			cmp byte [INPUT],48 		;ascii 0=48
			jl .error
			cmp byte [INPUT],57 		;ascii 9=57
			jg .error
			mov dword [INP_LENGTH],1
			call add_num_to_stack
			jmp _while
		.error:
			push ILLEGAL_COMMAND
			push STR_FORMAT
			call printf
			add esp,8
			jmp _while

end_while:
		
	popad			; Restore registers
	mov	esp, ebp	; Function exit code
	pop	ebp
	ret

;**************************************************************************************************
;*************************************** quit *****************************************************

quit_func:
	push ebp
	mov	ebp, esp	; Entry code - set up ebp and esp	

	mov byte [WHILE_FLAG],0

	mov	esp, ebp	; Function exit code
	pop	ebp
	ret


;**************************************************************************************************
;*********************************** add_num_to_stack *********************************************

add_num_to_stack: 

	push ebp
	mov	ebp, esp	; Entry code - set up ebp and esp	
	pushad			; Save registers

	mov edx,0 						; edx=0
	cmp dword [STACK_SIZE],5 		; MAX size of stack
	jl .add 							; OK to add to stack
	jmp .overflow

	.add:

		mov ebx,0 				  		; ebx=0
		mov dword ecx,[OFFSET]        	; ecx= points to first ascii byte
		
		cmp dword [INP_LENGTH],0
		je .add_to_stack

		mov byte bl,[INPUT+ecx]   	
		cmp byte bl,48 		;ascii 0=48
		jl .error
		cmp byte bl,57 		;ascii 9=57
		jg .error

		sub bl,48 	     	      		; convert to num value
		
		dec dword [INP_LENGTH]	
		inc dword [OFFSET]
		mov ecx, [OFFSET]
		
		cmp dword [INP_LENGTH],0
		je .add_1_digit
		
		mov byte bh,[INPUT+ecx]   		; bh = second digit
		cmp byte bh,48 					;ascii 0=48
		jl .error
		cmp byte bh,57 					;ascii 9=57
		jg .error

		sub bh,48 				  		; convert to number value
		dec dword [INP_LENGTH]	

		shl bl,4 				 		; move digit to left side of byte
		or bl,bh 				  		; bl=2 digits of number

		push LINK_SIZE 					; bytes size for malloc
		CALL malloc 			        ; eax = pointer to memory alloc
		add esp,4
		mov byte [eax+DATA],bl          ; put data in link
		mov edx,[LAST_LINK_PTR]
		mov dword [eax+NEXT],edx		; put next in link
		mov dword [LAST_LINK_PTR], eax 	; eax= the address of the beginning of malloc   
		inc dword [OFFSET] 		 		; next byte to take
		
		jmp .add 			        	; back to next input

	.add_to_stack:	

			mov dword ebx,[STACK_SIZE]
			shl ebx, 2 					; multiply by 4
			mov [STACK+ebx],eax 		; add to stack the head link
			inc dword [STACK_SIZE]
			jmp .ret

	.add_1_digit: 						    ; odd digit, one number left to add
			not bh 							; bh=F
			shl bh,4
			or bl,bh
			push LINK_SIZE 					; bytes size for malloc
			CALL malloc 			        ; eax = pointer to memory alloc
			add esp,4
			mov byte [eax+DATA],bl          ; put data in link
			mov edx,[LAST_LINK_PTR]
			mov dword [eax+NEXT],edx		; put next in link
			mov [LAST_LINK_PTR],eax 	    			; edx= pointer to link
			inc dword [OFFSET] 		 		; next byte to take
			jmp .add_to_stack

	.error:
			push ILLEGAL_COMMAND
			push STR_FORMAT
			call printf
			add esp,8
			mov byte [COMMAND],2

	.ret:
			cmp byte [COMMAND],2
			je .finish
			mov byte [COMMAND],0
		.finish:
			popad				; Restore registers
			mov	esp, ebp		; Function exit code
			pop	ebp
			ret

 	.overflow:

		push STACK_OVERFLOW
		push STR_FORMAT
		call printf
		add esp,8
		mov byte [COMMAND],2		
		
		popad			; Restore registers
		mov	esp, ebp	; Function exit code
		pop	ebp
		ret

;**************************************************************************************************
;*************************************** POP-func *************************************************

pop_func:
	
	push	ebp
	mov	ebp, esp						; Entry code - set up ebp and esp	
	pushad								; Save registers	
	mov dword [PRINT_COUNT],0 				
	cmp dword [STACK_SIZE],1 			; not empty
	jl .error
	mov dword eax,[STACK_SIZE] 			;eax=stacksize-1
	dec eax
	shl eax,2
	mov dword ecx,[STACK+eax]           ; ecx= pointer to link
	mov ebx,0 							; reset ebx=0
	mov byte bl,[ecx+DATA] 				; bl= data of link
	mov edi,1 							; edi= flag of first digit check
	.push_all_to_stack:
		
		push ebx 			    		; enter 2 digits
		inc dword [PRINT_COUNT] 		; counter++
		mov eax,[ecx+NEXT]
		cmp eax,0 						; ecx= ptr to next link (check if =0)
		je .print
		mov ecx,eax						; eax= pointer to next
		mov bl,[eax+DATA]	 			; bl = data
		jmp .push_all_to_stack

	.print:
		cmp dword [PRINT_COUNT],0
		je .ret	 
		
		mov dword ebx, [esp]
		add esp,4
		mov eax,ebx

		shr al,4
		cmp al,15 						; left digit = f
		jne .check_0
		shl bl,4
		mov bh,0
		shr bl,4
		push ebx
		push HEX_FORMAT
		CALL printf
		add esp,8
		dec dword [PRINT_COUNT]     	; counter--
		jmp .print

	.check_0:
		cmp edi,1
		je .print_reg
		cmp al,0
		jne .print_reg
		shl bl,4
		mov bh,0
		shr bl,4
		push ebx
		push HEX0_FORMAT
		call printf
		add esp,8
		dec dword [PRINT_COUNT]     	; counter--
		jmp .print

	.print_reg:
		mov edi,0
		push ebx
		push HEX_FORMAT
		call printf
		add esp,8
		dec dword [PRINT_COUNT]     	; counter--
		jmp .print

	.error:
		push STACK_UNDERFLOW 				; print error statement
		push STR_FORMAT
		call printf
		add esp,8
		mov byte [COMMAND],2

		popad							; Restore registers
		mov	esp, ebp					; Function exit code
		pop	ebp
		ret

	.ret:
		cmp byte [COMMAND],2
		je .finish1
		mov byte [COMMAND],1 	     	
	.finish1:
		cmp byte [DEBUG],0
		je .finish
		push RESULT
		push STR_FORMAT
		call printf
		add esp,8 
		call print_debug

	.finish:
		call free_list
		popad							; Restore registers
		mov	esp, ebp					; Function exit code
		pop	ebp
		ret


;**************************************************************************************************
;******************************************* FREE ************************************************

free_list:

	push	ebp
	mov	ebp, esp						; Entry code - set up ebp and esp	
	pushad								; Save registers	

	dec dword [STACK_SIZE]
	mov dword eax,[STACK_SIZE]
	shl eax,2
	mov ebx, [STACK+eax]
	mov ebx,0

	.ret:
		popad							; Restore registers
		mov	esp, ebp					; Function exit code
		pop	ebp
		ret

;**************************************************************************************************
;******************************************* AND - main *******************************************

and_op:
	
	push	ebp
	mov	ebp, esp						; Entry code - set up ebp and esp	
	pushad								; Save registers	

	cmp dword [STACK_SIZE],2
	jl .underflow

	mov eax,[STACK_SIZE]
	sub eax,2
	push eax
	call change_to_even
	add esp,4
	inc eax
	push eax
	call change_to_even
	add esp,4
	call and_equals

	jmp .ret

	.underflow:
		push STACK_UNDERFLOW 				; print error statement
		push STR_FORMAT
		call printf
		add esp,8
		mov byte [COMMAND],2

	.ret:
		cmp byte [COMMAND],2
		je .finish
		mov byte [COMMAND],1
	.finish:
		popad							; Restore registers
		mov	esp, ebp					; Function exit code
		pop	ebp
		ret

;**************************************************************************************************
;******************************************* AND -evens *******************************************

and_equals:
	
	push	ebp
	mov	ebp, esp						; Entry code - set up ebp and esp	
	pushad								; Save registers	

	mov dword [COUNT1],0
	mov edi,1 							; flag first list 
	cmp dword [STACK_SIZE],2 			; not empty
	jl .error

	mov dword eax,[STACK_SIZE] 			; eax=stacksize-1
	mov ebx,eax
	sub ebx,2
	shl ebx,2
	mov dword ecx,[STACK+ebx]           ; ecx= pointer to first list

	dec eax
	shl eax,2
	mov dword ebx,[STACK+eax]           ; ebx= pointer to second list


	.push_all_to_stack:
		
		mov eax,0 							; reset eax=0
		cmp edi,0
		jle .add_new_list

		mov byte al,[ecx+DATA] 				; al= data of first list
		mov byte ah,[ebx+DATA]				; ah= list2
	 	and al,ah
	 	mov ah,0
			
		push eax 			    		; enter 2 digits
		inc dword [COUNT1]

		mov esi,[ecx+NEXT]
		mov ecx,esi 					;ecx = next link

		mov esi,[ebx+NEXT]
		mov ebx,esi 					;ebx = next link

		cmp ecx,0 						
		jne .keep_flag1
		dec edi

	.keep_flag1:
		cmp ebx,0
		jne .keep_flag2
		dec edi

	.keep_flag2:

		jmp .push_all_to_stack

	.error:
		push STACK_UNDERFLOW 				; print error statement
		push STR_FORMAT
		call printf
		add esp,8
		mov byte [COMMAND],2

	.ret:
		cmp byte [COMMAND],2
		je .finish
		mov byte [COMMAND],1
	.finish:
		popad							; Restore registers
		mov	esp, ebp					; Function exit code
		pop	ebp
		ret

	.add_new_list:

		mov dword [LAST_LINK_PTR],0

		.add:
			cmp dword [COUNT1],0
			je .put_in_our_stack

			mov dword ebx,[esp]			;ebx=value of and (in bl)
			push LINK_SIZE
			Call malloc
			add esp,8

			mov byte [eax+DATA],bl
			mov dword ebx,[LAST_LINK_PTR] 	; ebx= the current links next ptr
			mov dword [eax+NEXT],ebx
			dec dword [COUNT1]
			mov dword [LAST_LINK_PTR],eax 	    			
			jmp .add

        .put_in_our_stack:

        	dec dword [STACK_SIZE]
        	mov dword ebx,[STACK_SIZE]
			shl ebx, 2 					    ; multiply by 4
			mov dword [STACK+ebx],0 		; add to stack the head link
			sub ebx,4
			mov dword ecx,[LAST_LINK_PTR]
			mov dword [STACK+ebx],ecx
			mov dword eax,[STACK+ebx]
			jmp .ret
		

;*******************************************************************************************************
;******************************************* ADD - main    *********************************************

add_op:
	
	push	ebp
	mov	ebp, esp						; Entry code - set up ebp and esp	
	pushad								; Save registers	

	cmp dword [STACK_SIZE],2
	jl .underflow

	mov eax,[STACK_SIZE]
	sub eax,2
	push eax
	call change_to_even
	add esp,4
	inc eax
	push eax
	call change_to_even
	add esp,4
	call add_same_oddity
	jmp .ret
	
	.underflow:
		push STACK_UNDERFLOW 				; print error statement
		push STR_FORMAT
		call printf
		add esp,8
		mov byte [COMMAND],2


	.ret:
		cmp byte [COMMAND],2
		je .finish
		mov byte [COMMAND],1
	.finish:
		popad							; Restore registers
		mov	esp, ebp					; Function exit code
		pop	ebp
		ret


;*******************************************************************************************************
;******************************************* ADD-both even *********************************************


add_same_oddity:
	
	push	ebp
	mov	ebp, esp						; Entry code - set up ebp and esp	
	pushad								; Save registers	

	mov dword [COUNT1],0
	mov edi,1 							; flag first list 
	mov esi,1 							; flag list 2 

	cmp dword [STACK_SIZE],2 			; not empty
	jl .error

	mov dword eax,[STACK_SIZE] 			; eax=stacksize-1
	mov ebx,eax
	sub ebx,2
	shl ebx,2
	mov dword ecx,[STACK+ebx]           ; ecx= pointer to list1- edi

	dec eax
	shl eax,2
	mov dword ebx,[STACK+eax]           ; ebx= pointer to list2- esi

	clc 								; clear carry flag
	mov byte [CARRY],0

	.push_all_to_stack:
		
		mov eax,0 							; reset eax=0

		cmp edi,0
		jle .put_zero
		mov byte al,[ecx+DATA] 				; al= data of first list
		jmp .cont
	
	.put_zero:
		cmp esi,0
		jle .add_new_list
		mov al,0
	
	.cont:
		cmp esi,0
		jle .put_zero2
		mov byte ah,[ebx+DATA]				; ah= list2
		jmp .cont2

	.put_zero2:
		mov ah,0

	.cont2:
		cmp byte [CARRY],0
	 	je .add_no_carry
	 	inc al

	.add_no_carry:
	 	add al,ah
	 	daa
	 	mov byte [CARRY],0
	 	jnc .dont_set_carry
	 	inc byte [CARRY]
	
	.dont_set_carry:
	 	mov ah,0
			
		push eax 			    		; enter 2 digits
		inc dword [COUNT1]

		cmp edi,0
		jle .no_next1
		mov edx,[ecx+NEXT]
		mov ecx,edx 					;ecx = next link
	
	.no_next1:

		cmp esi,0
		jle .no_next2
		mov edx,[ebx+NEXT]
		mov ebx,edx 					;ebx = next link
	
	.no_next2:
		cmp ecx,0 						
		jne .keep_flag1
		dec edi

	.keep_flag1:
		cmp ebx,0
		jne .keep_flag2
		dec esi
	
	.keep_flag2:
		jmp .push_all_to_stack

	.error:
		push STACK_UNDERFLOW 				; print error statement
		push STR_FORMAT
		call printf
		add esp,8
		mov byte [COMMAND],2

	.ret:
		cmp byte [COMMAND],2
		je .finish
		mov byte [COMMAND],1
	.finish:
		popad							; Restore registers
		mov	esp, ebp					; Function exit code
		pop	ebp
		ret

	.add_new_list: 
		mov dword [LAST_LINK_PTR],0
		cmp byte [CARRY],0
		je .add

		mov ebx,1
		push ebx
		inc dword [COUNT1]
		
		.add:

			cmp dword [COUNT1],0
			je .put_in_our_stack

			mov dword ebx,[esp]			;ebx=value of and (in bl)
			push LINK_SIZE
			Call malloc
			add esp,8
			mov byte [eax+DATA],bl
			mov dword ebx,[LAST_LINK_PTR] 	; ebx= the current links next ptr
			mov dword [eax+NEXT],ebx
			dec dword [COUNT1]
			mov dword [LAST_LINK_PTR],eax 	    			
			jmp .add

        .put_in_our_stack:

        	dec dword [STACK_SIZE]
        	mov dword ebx,[STACK_SIZE]
			shl ebx, 2 					    ; multiply by 4
			mov dword [STACK+ebx],0 		; add to stack the head link
			sub ebx,4
			mov dword ecx,[LAST_LINK_PTR]
			mov dword [STACK+ebx],ecx
			mov dword eax,[STACK+ebx]
			jmp .ret


;*************************************************************************************************************
;******************************************* Change to even **************************************************


change_to_even:

	push	ebp
	mov	ebp, esp	 ; Entry code - set up ebp and esp	
	pushad			 ; Save registers	
	mov esi,[ebp+8]  ; get argument 1
	
	cmp dword [STACK_SIZE],0
	jl .underflow

	shl esi,2
	mov dword edi,[STACK+esi]  		;edi=ptr to list

	mov dword [TEMP_LINK],edi
	mov bl,[edi+DATA] 				 
	mov bh,bl 						;bh=data
	shr bl,4
	cmp bl,15 						;bl=left digit
	jne .ret 						; if no f= even number of digits,ok

	shl bh,4
	shr bh,4 						;bh=right digit	(_ _ _ _ right)

	mov dh,-1 						;patch (for .one_digit)

	mov ecx,[edi+NEXT] 				;ecx=next link
	cmp ecx,0
	je .one_digit

	mov dl,[ecx+DATA] 				;dl=data of next
	mov dh,dl
	shr dh,4 						;dh=left digit (_ _ _ _ left)

	shl dl,4 						;dl=right digit (right _ _ _ _)
	or bh,dl 						;bh=corrected first link

	mov eax,[ecx+NEXT]
	mov ecx,eax

	pushad
	push LINK_SIZE
	call malloc 					;eax=ptr to malloc
	add esp,4
	mov dword [TEMP],eax
	popad
	mov dword eax,[TEMP]
	
	mov byte [eax+DATA],bh
	mov dword [eax+NEXT],0
	mov dword [TEMP_LINK],eax 		;TEMP_LINK=needs to connect next
	mov dword [STACK+esi],eax 	    ;stack receives the head


	.loop:

		cmp ecx,0
		je .one_digit
		mov byte bh, [ecx+DATA] 			;bh=data of next
		mov bl,bh 							;bl=copy of next data

		shl bl,4 							;bl= (right _ _ _ _)
		or bl,dh
		
		mov dh,bh
		shr dh,4 							;dh= (_ _ _ _ right)
		
		pushad
		push LINK_SIZE
		call malloc 						;eax=ptr to malloc
		add esp,4
		mov dword [TEMP],eax
		popad
		mov dword eax,[TEMP]

		mov byte [eax+DATA],bl
		mov dword ebx,[TEMP_LINK]
		mov dword [ebx+NEXT],eax
		mov dword [eax+NEXT],0
		mov dword [TEMP_LINK],eax 			;TEMP_LINK=needs to connect next
		mov eax,[ecx+NEXT]
		mov ecx,eax 						;ecx= ptr to next

		jmp .loop


	.one_digit: 					;case=one digit

		pushad

		push LINK_SIZE
		call malloc
		add esp,4
		mov dword [TEMP],eax
		popad
		mov eax,[TEMP]

		cmp dh,-1
		je .add_bh
		mov byte [eax+DATA],dh
		mov dword ebx,[TEMP_LINK]
		mov dword [ebx+NEXT], eax
		mov dword [eax+NEXT],0
		jmp .ret

	.add_bh:
		mov byte [eax+DATA],bh
		mov [STACK+esi],eax
		jmp .ret

	.overflow:

		push STACK_OVERFLOW
		push STR_FORMAT
		call printf
		add esp,8
		mov byte [COMMAND],2		
		jmp .ret
	
	.underflow:
		push STACK_UNDERFLOW 				; print error statement
		push STR_FORMAT
		call printf
		add esp,8	
		mov byte [COMMAND],2


	.ret:	
		popad			; Restore registers
		mov	esp, ebp	; Function exit code
		pop	ebp
		ret



;*************************************************************************************************************
;*******************************************  DUP FUNC *******************************************************


dup_func:

	push	ebp
	mov	ebp, esp	 ; Entry code - set up ebp and esp	
	pushad			 ; Save registers	

	cmp dword [STACK_SIZE],5
	je .overflow
	cmp dword [STACK_SIZE],1
	jl .underflow

	mov dword [COUNT1],0 		;COUNT1=0 (PUSH)
	mov eax,[STACK_SIZE]		;eax=num of elements in stack
	dec eax
	shl eax,2
	mov dword ebx,[STACK+eax] 	;ebx=ptr to list
	mov dword [TEMP_LINK],0 	;TEMP_LINK= ptr to next of the following link
	.push_all:

		cmp ebx,0
		je .duplicate
		inc dword [COUNT1]
		push ebx
		mov eax,[ebx+NEXT]
		mov ebx,eax 			    ;ebx=next ptr
		jmp .push_all

	.duplicate:

		cmp dword [COUNT1],0 	    ; no more elements to copy
		je .add_to_stack
		mov dword ebx,[esp]      	;ebx=last link
		add esp,4 					; for next loop
		
		pushad
		push LINK_SIZE
		call malloc 			    ;eax=ptr to malloc memory
		add esp,4
		mov dword [TEMP],eax
		popad
		mov dword eax,[TEMP]        ;eax=ptr to malloc memory
		.sdf:

		mov byte cl,[ebx+DATA]
		.asdfas:
		mov byte [eax+DATA],cl 		    ;eax.data= ebx.data
		mov dword ecx,[TEMP_LINK]

		mov [eax+NEXT],ecx 		    ;ebx.next=TEMP_LINK
		mov dword [TEMP_LINK],eax   ;TEMP_LINK=curr link
		dec dword [COUNT1] 		    ; PUSH COUNT--
		jmp .duplicate

	.add_to_stack:
		mov dword ecx,[TEMP_LINK]
		mov dword eax,[STACK_SIZE]
		shl eax,2
		mov [STACK+eax],ecx
		inc dword [STACK_SIZE]
		jmp .ret

	.underflow:
		push STACK_UNDERFLOW 				; print error statement
		push STR_FORMAT
		call printf
		add esp,8	
		mov byte [COMMAND],2		
		jmp .ret

	.overflow:
		push STACK_OVERFLOW 				; print error statement
		push STR_FORMAT
		call printf
		mov byte [COMMAND],2		
		add esp,8	

	.ret:	
		cmp byte [COMMAND],2
		je .finish
		push RESULT
		push STR_FORMAT
		Call printf
		add esp,8
		call print_debug
		mov byte [COMMAND],2

	.finish:

		popad			; Restore registers
		mov	esp, ebp	; Function exit code
		pop	ebp
		ret


;**************************************************************************************************
;*************************************** PRINT DEBUG **********************************************

print_debug:
	
	push	ebp
	mov	ebp, esp						; Entry code - set up ebp and esp	
	pushad								; Save registers	

	mov dword [PRINT_COUNT],0 				
	cmp dword [STACK_SIZE],1 			; not empty
	jl .error
	mov dword eax,[STACK_SIZE] 			;eax=stacksize-1
	dec eax
	shl eax,2
	mov dword ecx,[STACK+eax]           ; ecx= pointer to link
	mov ebx,0 							; reset ebx=0
	mov byte bl,[ecx+DATA] 				; bl= data of link
	mov edi,1 							; edi= flag of first digit check
	
	.push_all_to_stack:
		
		push ebx 			    		; enter 2 digits
		inc dword [PRINT_COUNT] 		; counter++
		mov eax,[ecx+NEXT]
		cmp eax,0 						; ecx= ptr to next link (check if =0)
		je .print
		mov ecx,eax						; eax= pointer to next
		mov bl,[eax+DATA]	 			; bl = data
		jmp .push_all_to_stack

	.print:
		cmp dword [PRINT_COUNT],0
		je .ret	 
		
		mov dword ebx, [esp]
		add esp,4
		mov eax,ebx

		shr al,4
		cmp al,15 						; left digit = f
		jne .check_0
		shl bl,4
		mov bh,0
		shr bl,4
		
		push ebx 
		push HEX_FORMAT
		CALL printf
		add esp,8
		
		dec dword [PRINT_COUNT]     	; counter--
		jmp .print

	.check_0:
		cmp edi,1
		je .print_reg
		cmp al,0
		jne .print_reg
		shl bl,4
		mov bh,0
		shr bl,4
		
		push ebx 				
		push HEX0_FORMAT
		call printf
		add esp,8
		
		dec dword [PRINT_COUNT]     	; counter--
		jmp .print

	.print_reg:
		mov edi,0
		
		push ebx 				
		push HEX_FORMAT
		call printf
		add esp,8
		
		dec dword [PRINT_COUNT]     	; counter--
		jmp .print

	.error:
		push STACK_UNDERFLOW 			; print error statement
		push STR_FORMAT
		call printf
		add esp,8
		mov byte [COMMAND],2		
		popad							; Restore registers
		mov	esp, ebp					; Function exit code
		pop	ebp
		ret

	.ret:
		mov byte [COMMAND],3
		popad							; Restore registers
		mov	esp, ebp					; Function exit code
		pop	ebp
		ret