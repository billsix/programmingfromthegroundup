%include "xnu.asm"
%include "record-def.asm"

extern count_chars
extern read_record
extern write_newline
extern allocate_init
extern allocate
extern deallocate

    section .data
file_name:
    ; Null-terminated string as the user_addr_t path parameter of
    ; the open syscall
    db 'test.dat', 0

record_buffer_ptr:
    ; New dynamically allocated buffer
    dq 0

    section .text
    global _main
_main:
    ; These are the locations on the stack
    ; we will store the input and output descriptors
    ; (FYI - we could have used memory addresses in 
    ; a .data section instead)
    ST_INPUT_DESCRIPTOR equ -8
    ST_OUTPUT_DESCRIPTOR equ -16

    ; main function prologue
    push rbp
    mov rbp, rsp

    call allocate_init

    push RECORD_SIZE
    call allocate
    mov [rel record_buffer_ptr], rax

    ; Copy the stack pointer to rbp
    mov rbp, rsp
    ; Allocate space to store the file descriptors
    sub rsp, 16

    ; Open the file
    mov rax, SYS_OPEN
    lea rdi, [rel file_name]
    mov rsi, O_RDONLY
    mov rdx, 0666
    syscall

    ; @lmartinho: Check if open was successful
    cmp rax, 2
    je exit_failed_open

    ; Save the file descriptor
    mov [rbp + ST_INPUT_DESCRIPTOR], rax

    ; Even though it's a constant, we are
    ; saving the output file descriptor in a local
    ; variable so that if we later
    ; decide that it isn't always going to 
    ; be STDOUT, we can change it easily.
    mov qword [rbp + ST_OUTPUT_DESCRIPTOR], STDOUT

record_read_loop:
    push qword [rbp + ST_INPUT_DESCRIPTOR]
    push qword [rel record_buffer_ptr]
    call read_record
    add rsp, 16

    ; Returns the number of bytes read.
    ; If it isn't the same number we 
    ; requested, then it's either an 
    ; end-of-file, or an error, so we're
    ; quitting
    cmp rax, RECORD_SIZE
    jne finished_reading

    ; Otherwise print out the first name
    ; but first, we must know its size
    push qword [rel record_buffer_ptr + RECORD_FIRSTNAME]
    call count_chars
    add rsp, 8

    ; user_ssize_t write(int fd, user_addr_t cbuf, user_size_t nbyte)
    mov rdi, [rbp + ST_OUTPUT_DESCRIPTOR]               ; fd
    mov rsi, [rel record_buffer_ptr + RECORD_FIRSTNAME] ; cbuf
    mov rdx, rax                                        ; nbyte
    mov rax, SYS_WRITE                                  ; write
    syscall

    push qword [rbp + ST_OUTPUT_DESCRIPTOR]
    call write_newline
    add rsp, 8

    jmp record_read_loop

finished_reading:
    push qword [rel record_buffer_ptr]
    call deallocate 

    ; main function epilogue
    mov rsp, rbp
    pop rbp

    mov rax, SYS_EXIT
    mov rdi, 0
    syscall

exit_failed_open:
    mov rax, SYS_EXIT
    mov rdi, 254
    syscall