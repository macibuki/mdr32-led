	TTL "Milandr MDR32F9Q2I assembler template"
	SUBT "Copyright © D.A. Zhizhelev http://gimmor.blogspot.com/"
	; Пример минимального начального ассемблерного файла для микроконтроллера, с комментариями
	; Микроконтроллер: Миландр MDR32F9Q2I, 32-бит, ARM Cortex-M3
	; Сайт производителя: http://milandr.ru/
	; Язык ассемблера - UAL для ассемблера armasm, среды Keil uVision v.4.
	; Мигание светодиодом, подключенным к порту PA.1
	; Отладочная плата: MDR32-Solo, http://gimmor.blogspot.com/2013/03/mdr32-solo-mdr32f9q2i.html
	; Простейший пример, когда микроконтроллер работает на встроённом 8МГц RC-генераторе,
	; затем включается внешний кварцевый генератор (в моём случае 12 МГц)
	; Сопутствующая заметка: http://gimmor.blogspot.com/2013/03/mdr32f9q2i-arm-asm-keil-example.html
	; Файл предоставлен без каких-либо гарантий, для информационных целей. Применение на свой страх и риск.

STACK_TOP 			EQU 0x20000100

; Определение базового адреса блока управления системой SCB
MDR_SCB				EQU 0xE000ED00

; Смещение регистра идентификации процессора, относительно адреса MDR_SCB
; Регистр доступен для чтения
; У микроконтроллера Миландр MDR32F9Q2I, содержиться значение 0x412FC230 - оно общее для семейства мк 1986
MDR_SCB_CPUID		EQU 0x000

MDR32F9Q2I_CPUID	EQU 0x412FC230	; Значение CPUID


; Батарейный домен MDR_BKP
MDR_BKP				EQU 0x400D8000

; Смещения регистров батарейного домена
REG_OE				EQU 0x38	 
REG_0F				EQU 0x3C	; Содержит информацию о готовности некоторых тактовых генераторов


; Определения блока тактовых частот
MDR_RST_CLK			EQU 0x40020000

; Смещения регистров
CLOCK_STATUS		EQU 0x00	; Регистр работы внешнего HSE генератора, PLL, USB PLL 
HS_CONTROL			EQU	0x08	; Регистр управления внешним HSE-генератором
PER_CLOCK			EQU 0x1C	; Регистр тактирования периферии
CPU_CLOCK			EQU	0x0C	; Регистр настройки тактовой частоты
PLL_CONTROL			EQU 0x04	; Регистр умножения частоты


; Маска включения внешнего HSE генератора
MDR_HSE_ON			EQU 0x1

; Маска для регистра CPU_CLOCK
MDR_CPU_CLOCK		EQU 0x102
MDR_CPU_CLOCK_HSE	EQU 0x82 
		
; Маска для регистра PLL_CONTROL
; Состояние битов см. спецификацию, таблицу 82
; 0x504 - умножитель на 5 + 1 и включени
MDR_CPU_PLL			EQU 0x0504
MDR_ADD_PPLON		EQU 0x04	; Бит №2 - бит выбор источника для CPU_C2

; Маски для включения периферии
MDR_PORTA_EN		EQU	0x00200000	; Маска включения тактирования порта A
MDR_BKP_EN			EQU 0x08000000	; Маска включения тактирования батарейного домена



; Определения порта A.
; Адреса конфигурационных регистров порта A
MDR_PORTA 			EQU 0x400A8000
; Смещения регистров порта (любого), относительно базового адреса 
PORT_FUNCTION		EQU 0x08
PORT_ANALOG			EQU 0x0C
PORT_OE				EQU 0x04
PORT_PWR			EQU 0x18
PORT_RXTX			EQU 0x00
PORT_PD				EQU 0x14


; Маски значений для конфигурационных регистров порта A.
; Значения зададим в шестнадцатеричной форме, их получим из бинарного представления с помощью калькулятора в операционной системе
FUNC_A1				EQU	0x00	; Режим порта
ANALOG_A1			EQU 0x02
OE_A1				EQU 0x02
RXTX_A1				EQU 0x02
PWR_A1				EQU 0x0C	; Максимальный фронт 


	; Миландр MDR32F9Q2I использует набор инструкций Thumb
	THUMB 
	; Выравнивание по границе 8 байт
	PRESERVE8

	; Определение индивидуальных именованных областей кода
	; В данном случае, определяется область с именем RESET, содержащая код - аттрибут CODE, доступная только для чтения READONLY
	AREA RESET, CODE, READONLY

	; Это таблица используемых векторов прерываний
	;Директива DCD размещает память, выровненную по 4-байтной границе
	DCD STACK_TOP ; Указатель на вершину стека
	DCD Start+1 ; Вектор сброса




	; Начало программы
	; Директива ENTRY указывает на вход в программу. Обязательна
	ENTRY
Start	 PROC
	
	; Определим идентификацию процессора. Это не нужно для моргания светодиодом, но пригодиться при отладке
	; В принципе при отладке через J-Link JTAG, в регистр R4 попадет CPUID нашего микроконтроллера
	MOV32 R3, MDR_SCB
	LDR R4, [R3, #MDR_SCB_CPUID] ; В регистр R4 заносим значение регистра MDR_SCB_CPUID, исп. базовый адрес из регистра R3
	
	; Работа с тактовой подсистемой
	MOV32 R3, MDR_RST_CLK

	; Включение тактирования выбранной периферии, в регистре PER_CLOCK тактовой подсистемы RST_CLK
	; Данная операция обязательна, без неё не работают порты
	; см. Таблица 94 спецификации
	LDR R4, [R3, #PER_CLOCK] 	; MDR_RST_CLK_PER_CLOCK
	ORR R4, #MDR_PORTA_EN 		; Включаем только порт A
	ORR R4, #MDR_BKP_EN			; Включаем тактирование батарейного домена
	STR R4, [R3, #PER_CLOCK] 	; Сохраняем новое значение регистра R4, по адресу, вычисленному из R3 и смещения PER_CLOCK, т.е. в регистр MDR_RST_CLK_PER_CLOCK


	; Посмотрим, включён ли внутренний HSI генератор
	; Эта пара команд, также не нужна, для целей моргания, но поможет при отладке
	MOV32 R3, MDR_BKP			; Базовый адрес батарейного домена
	LDR R4, [R3,#REG_0F]		; Регистр флагов REG_0F батарейного домена
	; По результатам первого запуска в регистре содержится 0
	; По идее, должен быть включен внутренний генератор, а он выглядит выключенным
	; Предположение о том, что должна быть включена тактовая частота батарейного домена (чтобы были значения) подтвердилась
	; Маска готовности HSI - 0x00C00000 (22 и 23 биты)
	; Маска включения батарейного домена 0x08000000
	; В тестовом примере, она уже включается
	
	
	; Теперь предварительно посмотрим состояние регистра MDR_RST_CLK_CPU_CLOCK, отвечающего за частоту CPU
	; Генератор HSE запускается при появлении питания UCC и сигнала разрешения HSEON в регистре HS_CONTROL.
	; При выходе HSE-генератора в нормальный режим работы, вырабатывает сигнал HSERDY в регистре CLOCK_STATUS.

	; Работа с тактовой подсистемой
	MOV32 R3, MDR_RST_CLK
	; Смотрим исходное состояние регистра  MDR_RST_CLK_CLOCK_STATUS
	LDR R4, [R3, #CLOCK_STATUS] ; MDR_RST_CLK_CLOCK_STATUS
	; Важны первые 3 бита, 
	; Нули свидетельствуют о том, что HSE выключен, PLL выключена, USB PLL выключена

	; Включение внешнего кварцевого генератора
	LDR R4, [R3, #HS_CONTROL] ; MDR_RST_CLK_HS_CONTROL - простой регистр
	ORR R4, #MDR_HSE_ON ; Бит включения внешнего кварцевого генератора
	STR R4, [R3, #HS_CONTROL] ; Сохраняем новое значение регистра R4, по адресу, вычисленному из R3 и смещения
	
	; Теперь надо подождать выхода генератора в рабочий режим (можно проверкой HSERDY)
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	; Тут можно поставить точку отладки и посмотреть состояние CLOCK_STATUS
	LDR R4, [R3, #CLOCK_STATUS] ; MDR_RST_CLK_CLOCK_STATUS
	
	
	
	; Работаем с регистром СPU_CLOCK подсистемы тактования RST_CLK
	LDR R4, [R3, #CPU_CLOCK] 	; MDR_RST_CLK_CPU_CLOCK
	ORR R4, #MDR_CPU_CLOCK_HSE 	; Маска включения HSE в качестве тактового генератора CPU
	STR R4, [R3, #CPU_CLOCK] 	; Сохраняем новое значение регистра R4, по адресу, вычисленному из R3 и смещения

	
	
	; Теперь можно проверить возможности блока PLL
;	LDR R4, [R3, #PLL_CONTROL]
;	ORR R4, #0x500
;	ORR R4, #0x04
;	STR R4, [R3, #PLL_CONTROL]
;	ORR R4, #0x0C
;	STR R4, [R3, #PLL_CONTROL]
;	MOV R4,#0
;	ORR R4, #0x500
;	ORR R4, #0x04
;	STR R4, [R3, #PLL_CONTROL]
	
	;ORR R4, #MDR_CPU_PLL ; Маска включения PLL и настройки множителя
	;STR R4, [R3, #PLL_CONTROL]
	
	; Теперь дожидаемся выхода на устойчивый режим PLL
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	LDR R4, [R3, #CLOCK_STATUS] ; MDR_RST_CLK_CLOCK_STATUS
	
	
	
	; И обновить CPU_CLOCK
;	LDR R4, [R3, #CPU_CLOCK] ; MDR_RST_CLK_CPU_CLOCK
;	ORR R4, #0x106 ; Маска добавления PLL
;	STR R4, [R3, #CPU_CLOCK] ; Сохраняем новое значение регистра R4, по адресу, вычисленному из R3 и смещения
	
	
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	
	
	
	
	
	
	; Начальная конфигурация линии №1 порта A. (PA.1)
	MOV32 R3, MDR_PORTA 			; Загрузить базовый 32-битный адрес порта A в регистр. Используется псевдоинструкция MOV32
	LDR R4, [R3, #PORT_FUNCTION] 	; Загрузить в регистр R4, значение заданное базовым адресом в регистре R3 и смещением (0x08), в данном случае, содержимое регистра порта A, MDR_PORTA_FUNC
	LDR R5, [R3, #PORT_ANALOG] 		; Загрузить в регистр R5, значение заданное базовым адресом в регистре R3 и смещением (0x0C), в данном случае, содержимое регистра порта A, MDR_PORTA_ANALOG
	LDR R6, [R3, #PORT_OE] 			; Загрузить в регистр R6, значение заданное базовым адресом в регистре R3 и смещением (0x04), в данном случае, содержимое регистра порта A, MDR_PORTA_OE
	LDR R7, [R3, #PORT_PWR] 		; Загрузить в регистр R7, значение заданное базовым адресом в регистре R3 и смещением (0x18), в данном случае, содержимое регистра порта A, MDR_PORTA_OE
	
	; Наложение масок
	ORR R4, #FUNC_A1
	ORR R5, #ANALOG_A1
	ORR R6, #OE_A1
	ORR R7, #PWR_A1
	
	; Выгрузка значений регистров общего назначения, в память регистров порта
	STR R4, [R3, #PORT_FUNCTION] 	; Выгрузить из регистра R4, в память с адресом, значение которого задано базовым адресом в регистре R3 и смещением (0x08), в данном случае, содержимое регистра порта A, MDR_PORTA_FUNC
	STR R5, [R3, #PORT_ANALOG] 		; Выгрузить из регистра R5, в память с адресом, значение которого задано базовым адресом в регистре R3 и смещением (0x0C), в данном случае, содержимое регистра порта A, MDR_PORTA_ANALOG
	STR R7, [R3, #PORT_PWR] 		; Выгрузить из регистра R6, в память с адресом, значение которого задано базовым адресом в регистре R3 и смещением (0x04), в данном случае, содержимое регистра порта A, MDR_PORTA_OE
	STR R6, [R3, #PORT_OE] 			; Выгрузить из регистра R6, в память с адресом, значение которого задано базовым адресом в регистре R3 и смещением (0x04), в данном случае, содержимое регистра порта A, MDR_PORTA_OE
	
	
	; Просмотр состояния
	LDR R4, [R3, #PORT_FUNCTION] 	; Загрузить в регистр R4, значение заданное базовым адресом в регистре R3 и смещением (0x08), в данном случае, содержимое регистра порта A, MDR_PORTA_FUNC
	LDR R5, [R3, #PORT_ANALOG] 		; Загрузить в регистр R5, значение заданное базовым адресом в регистре R3 и смещением (0x0C), в данном случае, содержимое регистра порта A, MDR_PORTA_ANALOG
	LDR R6, [R3, #PORT_OE] 			; Загрузить в регистр R6, значение заданное базовым адресом в регистре R3 и смещением (0x04), в данном случае, содержимое регистра порта A, MDR_PORTA_OE
	LDR R7, [R3, #PORT_PWR] 		; Загрузить в регистр R7, значение заданное базовым адресом в регистре R3 и смещением (0x18), в данном случае, содержимое регистра порта A, MDR_PORTA_OE
	
	; Бесконечный цикл - моргание светодиодом
loop
	; Установить линию в лог. 0 - в моём случае включить светодиод
	LDR R4, [R3, #PORT_RXTX] ; Загрузить в регистр R4, значение заданное базовым адресом в регистре R3 и смещением (PORT_RXTX), в данном случае, содержимое регистра порта A, MDR_PORTA_RXTX
	BIC R4, #RXTX_A1	; Сброс бита по маске
	STR R4, [R3, #PORT_RXTX] ; Выгрузить из регистра R4, в память с адресом, значение которого задано базовым адресом в регистре R3 и смещением 0x00
	LDR R4, [R3, #PORT_RXTX] ; Загрузить в регистр R4, значение заданное базовым адресом в регистре R3 и смещением (PORT_RXTX), в данном случае, содержимое регистра порта A, MDR_PORTA_RXTX

	; Пауза
	MOV32 R0, 2000000	; 8000000 Счёт
	
delay

	SUB R0, #1		; Декремент, результат сохраняется в R0
	CMP R0, #0		; Сравнение с 0
	BNE delay		; Если не равно 0, то продолжаем держать паузу
	 
	; Установить линию в лог. 1 - в моем случае выключить светодиод
	LDR R4, [R3, #PORT_RXTX] ; Загрузить в регистр R4, значение заданное базовым адресом в регистре R3 и смещением (PORT_RXTX), в данном случае, содержимое регистра порта A, MDR_PORTA_RXTX
	ORR R4, #RXTX_A1		 ; Операция ИЛИ по маске RXTX_A1
	STR R4, [R3, #PORT_RXTX] ; Выгрузить из регистра R4, в память с адресом, значение которого задано базовым адресом в регистре R3 и смещением PORT_RXTX
	
	; Пауза
	MOV32 R0, 2000000	; 8000000 Гц / 4 такта

delay2

	SUB R0, #1		; Декремент, результат сохраняется в R0
	CMP R0, #0		; Сравнение с 0
	BNE delay2		; Если не равно 0, то продолжаем держать паузу
	
	
	B loop
	
	
	; Конец программы
	ENDP
	 
	; Директива END - Конец файла. Обязательна
	END
