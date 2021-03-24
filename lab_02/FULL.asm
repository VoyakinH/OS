.386P ; Разрешение команд МП 386 и 486
; Структура для описания дескрипторов сегментов
descr struc 
limit dw 0      ; Граница (биты 0...15)
base_l dw 0     ; База, биты 0...15
base_m db 0     ; База, биты 16...23
attr_1 db 0     ; Байт атрибутов 1
attr_2 db 0     ; Граница (биты 16...19) и атрибуты 2
base_h db 0     ; База, биты 24...31
descr ends 

intr struc
offs_l dw 0     ; Смещение обработчика (биты 0...15)
sel    dw 0     ; Селектор сегмента команд
rsrv   db 0     ; Зарезервировано
attr   db 0     ; Атрибуты
offs_h dw 0     ; Смещение обработчика (биты 16...31)
intr ends

PROTECTED segment para public use32
assume CS:PROTECTED, DS:PROTECTED
; Таблица глобальных дескрипторов GDT 
GDT label byte 
gdt_null descr <>                     ; Нулевой дескриптор
gdt_data descr <data_size-1,,,92h>    ; Селектор 8, сегмент данных
gdt_code_16 descr <real_size-1,,,98h> ; Селектор 16, сегмент команд rm
gdt_stack descr <255,0,0,92h>         ; Селектор 24, сегмент стека
gdt_screen descr <4095,8000h,0Bh,92h> ; Селектор 32, видеобуфер
gdt_code_32 descr <pm_size-1,,,98h>   ; Селектор 40, сегмент команд pm
gdt_data_2 descr <0FFFFh,,,92h,11001111b>   ; Селектор 48, сегмент данных
gdt_size=$-gdt_null                   ; Размер GDT

IDT label word
;intr 12 dup (<>)
;exp_13 intr <0,40,0,8Eh,0>
;intr 18 dup (<>)
intr 32 dup (<>)
idt_08 intr <0,40,0,8Eh,0>
idt_09 intr <0,40,0,8Eh,0>
idt_size=$-IDT
         
; Поля данных программы
pdescr dw 0, 0, 0                           ; Псевдодескриптор 
attr1  db 0Ch                        
attr2  db 0Ah                    
mes1   db 'REAL MODE'             
mes2   db 'PROTECTED MODE'
timer  dd 0
start_pos  dw 500
escape db 0
mmask  db 0
smask  db 0
ascii  db 0, 0, 49, 50, 51, 52, 53, 54, 55, 56, 57, 48, 45, 61, 0, 0
       db 81, 87, 69, 82, 84, 89, 85, 73, 79, 80, 91, 93, 0, 0, 65, 83
       db 68, 70, 71, 72, 74, 75, 76, 59, 39, 96, 0, 92, 90, 88, 67
       db 86, 66, 78, 77, 44, 46, 47
data_size=$-GDT ; Размер сегмента данных

print_eax macro base
	local divide
	push EAX
	push EDI
	push EDX
	
	mov EDI, base
	
divide:	
	xor EDX, EDX
	div EDI
	add EDX, '0'
	mov DH, 1Eh
	mov ES:[EBX], DX
	sub BX, 2
	cmp EAX, 0
	jnz divide
	
	pop EDX
	pop EDI
	pop EAX
endm

exc proc
    iret
exc endp

new_timer proc
          push EAX
	  push EBX
	
	  mov EAX, timer
	  mov EBX, 380
	  print_eax 10
	  inc EAX
	  mov timer, EAX
	  ; Отправление команды ведущему контроллеру прерываний
	  mov	AL, 20h
	  out	20h, AL
	  pop EBX
	  pop EAX

	  iretd
new_timer endp

new_keyboard proc
	push EAX
	push EBX
	push EDX
	
	xor EAX, EAX
	; Получение скан кода клавиши с порта клавиатуры
	in AL, 60h
	cmp AL, 1Ch ; enter
	jne print
	mov escape, 1
	jmp exit

print:
	cmp AL, 80h ; Проверка что не отжата
	ja exit
	xor EDX, EDX
	mov BX, start_pos
	mov DL, ascii[EAX]
	mov DH, 1Eh
	mov ES:[BX], DX
	add BX, 2
	mov start_pos, BX

exit:	
	in Al, 61h
	or AL, 80h
	out 61h, AL
	
	mov AL, 20h
	out 20h, AL
	
	pop EDX
	pop EBX
	pop EAX
	iretd
new_keyboard endp

continue:
	mov AX, 8     ; Селектор сегмента данных
	mov DS, AX
	mov AX, 24    ; Селектор сегмента стека
	mov SS, AX
	mov AX, 32    ; Селектор сегмента видеобуфера
	mov ES, AX 
; Вывод сообщения о защищённом режиме работы процессора         
	mov DI, 770 
	mov CX, 14
	mov AH, attr2
	mov EBX, offset mes2
	
screen2:
	mov AL, byte ptr [EBX]
	stosw
	inc BX
	loop screen2
	
        sti
interrupts:
	test escape, 1	
	jz interrupts
	
	cli

mem:
	mov AX, 48
	mov FS, AX
	mov EBX, 100001h
	mov EDI, 49h ;рандомное значение
	mov ECX, 0FFFFFFFFh

check_mem:
	mov EDX, FS:[EBX]
	mov FS:[EBX], EDI ; запись сигнатуры
	mov EAX, FS:[EBX] ; чтение сигнатуры
	cmp EAX, EDI ; сравнение сигнатуры
	jne end_mem
	mov FS:[EBX], EDX
	inc EBX
	cmp ECX, EBX
	jne check_mem
	
end_mem:
	mov EAX, EBX
	mov BX, 336
	print_eax 10
	
	mov gdt_data.limit, 0FFFFh
	mov gdt_code_16.limit, 0FFFFh
	mov gdt_code_32.limit, 0FFFFh
	mov gdt_screen.limit, 0FFFFh
	mov gdt_stack.limit, 0FFFFh
	
	db 0EAh             ; Код команды дальнего перехода
	dd offset return    ; Смещение
	dw 16             ; Сегмент
	
; Процессор работает в реальном режиме
pm_size=$-GDT
PROTECTED ends


REAL segment para public use16 ; Используем по ум. 16-битовые адреса и операнды.
assume CS:REAL, DS:PROTECTED, SS:stk
main:
	xor EAX, EAX   ; Очистка EAX
	mov AX, PROTECTED 
	mov DS, AX     ; Загрузка сегментного адреса сегмента данных.
	
 ; Вывод сообщения о реальном режиме работы процессора
	mov AX, 0B800h
	mov ES, AX             ; Загрузка в ES адреса видеобуфера
	mov EBX, offset mes1
	mov AH, attr1
	mov DI, 460
	mov CX, 9
screen1:
	mov AL, byte ptr [EBX]
	stosw
	inc BX
	loop screen1
 
	mov AX, DS         ; Загружаем сегментный адрес сегмента данных
	; Вычисление 32-битного линейного адреса сегмента данных и загрузка
	; его в дескриптор сегмента данных GDT
	shl EAX, 4         ; Сдвиг содержимого EAX на 4 байта влево
	mov EBP, EAX       ; Сохранение EAX в EBP. Будет ещё использоваться
	mov EBX, offset gdt_data ; Загрузка адреса дескриптора данных
	mov [BX].base_l, AX      ; Загрузка младшей части базы
	rol EAX, 16              ; Обмен старшей и младшей половин EAX
	mov [BX].base_m, AL      ; Загрузка средней части базы
	; Вычисление 32-битного линейного адреса сегмента команд и загрузка
	; его в дескриптор сегмента команд GDT
	xor EAX, EAX       ; Очистка EAX
	mov AX, CS         ; Загрузка сегментного адреса сегмента команд
	shl EAX, 4         ; Сдвиг содержимого EAX на 4 байта влево
	mov EBX, offset gdt_code_16 ; Загрузка адреса дескриптора команд
	mov [BX].base_l, AX         ; Загрузка младшей части базы
	rol EAX, 16                 ; Обмен старшей и младшей половин EAX
	mov [BX].base_m, AL         ; Загрузка средней части базы
	; Вычисление 32-битного линейного адреса сегмента данных и загрузка
	; его в дескриптор сегмента данных GDT
	xor EAX,EAX        ; Очистка EAX
	mov AX, SS         ; Загрузка сегментного адреса сегмента стека
	shl EAX, 4         ; Сдвиг содержимого EAX на 4 байта влево
	mov EBX, offset gdt_stack; Загрузка адреса дескриптора стека
	mov [BX].base_l, AX      ; Загрузка младшей части базы
	rol EAX, 16              ; Обмен старшей и младшей половин EAX
	mov [BX].base_m, AL      ; Загрузка средней части базы
	; Вычисление 32-битного линейного адреса сегмента команд и загрузка
	; его в дескриптор сегмента команд GDT
	xor EAX, EAX       ; Очистка EAX
	mov AX, PROTECTED  ; Загрузка сегментного адреса сегмента команд
	shl EAX, 4         ; Сдвиг содержимого EAX на 4 байта влево
	mov EBX, offset gdt_code_32 ; Загрузка адреса дескриптора команд
	mov [BX].base_l, AX         ; Загрузка младшей части базы
	rol EAX, 16                 ; Обмен старшей и младшей половин EAX
	mov [BX].base_m, AL         ; Загрузка средней части базы
	; Подготовка псевдодескриптора
	mov dword ptr pdescr+2, EBP
	mov word ptr pdescr, gdt_size-1
	; Загрузка регистра GDTR
	lgdt pdescr
 
	cli           ; Запрет маскируемых прерываний
	mov AL, 80h
	out 70h, AL   ; Запрет немаскируемых прерываний
	
	; Сохранение маски порта.
	in AL, 21h
	mov mmask, AL
	in AL, 0A1h
	mov smask, AL
	; Изменение базового вектора.
	mov AL, 11h
	out 20h, AL
	mov AL, 20h
	out 21h, AL
	mov AL, 4
	out 21h, AL
	mov AL, 1
	out 21h, AL
	mov AL, 0FCh
	out 21h, AL
	mov AL, 0FFh
	out 0A1h, AL

        ; Вычисление адресов новых обработчиков прерываний
	mov EAX, offset new_timer
	mov idt_08.offs_l, AX
	shr EAX, 16
	mov idt_08.offs_h, AX
	
	mov EAX, offset new_keyboard
	mov idt_09.offs_l, AX
	shr EAX, 16
	mov idt_09.offs_h, AX
	
	;Подготовим псевдодескриптор и загрузим регистр IDTR
	mov word ptr pdescr, idt_size-1
	xor EAX, EAX
	mov EAX, offset IDT
	add EAX, EBP
	mov dword ptr pdescr+2, EAX
	lidt fword ptr pdescr
	
	; Открытие линии А20
	mov AL, 0D1h
	out 64h, AL 
	mov AL, 0DFh
	out 60h, AL
	
	; Переход в защищённый режим
	mov EAX, CR0 
	or  EAX, 1    ; Установка PE
	mov CR0, EAX
         
; Процессор работает в защищённом режиме

        ; Загрузка в CS:IP селектор:смещение точки continue
        db 66h
	db 0EAh            ; Код команды far jmp
	dd offset continue ; Смещение 
	dw 40              ; Селектор второго сегмента команд
	
return: 
        ; Закрытие линии А20
	mov AL, 0D1h
	out 64h, AL
	mov AL, 0DDh
	out 60h, AL
	
	mov EAX, CR0 
	and EAX, 0FFFFFFFEh ; Сброс бита PE
	mov CR0, EAX
	
	db 0EAh
	dw $+4
	dw REAL
	mov AX, PROTECTED
	mov DS, AX   ; Восстановление адресуемости данных
	mov AX, stk
	mov SS, AX   ; Восстановление адресуемости стека
	
	; Восстановление маски и контроллера прерываний
	mov AL, 11h
	out 20h, AL
	mov AL, 8
	out 21h, AL
	mov AL, 4
	out 21h, AL
	mov AL, 1
	out 21h, AL
	mov AL, mmask
	out 21h, AL
	mov AL, smask
	out 0A1h, AL
	
	mov pdescr, 3FFh
	mov word ptr pdescr+1, 0
	mov word ptr pdescr+2, 0
	lidt fword ptr pdescr

	sti          ; Разрешение маскируемых прерываний
	; Разрешение немаскируемых прерываний
	mov AL, 0 
	out 70h, AL  

; Вывод сообщения о реальном режиме работы процессора
	mov EBX, offset mes1
	mov AH, attr1
	mov DI, 1100
	mov CX, 9
screen3:
	mov AL, byte ptr [BX]
	stosw
	inc BX
	loop screen3

; Завершение программы
	mov AX, 4C00h
	int 21h 
real_size=$-main     ; Размер сегмента команд реальнольного режима
REAL ends          

stk segment stack 'stack'
	db 256 dup ('^')
stk ends 

end main 