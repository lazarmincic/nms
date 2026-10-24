li t0, 0
li t1, 2

test_loop: jal ra, target_label  

back_from_target:
    addi t0, t0, 1    # Increment loop counter
    blt t0, t1, test_loop # Loop back to run the exact same 'jal' instruction again

    # Exit Program (Linux sycall for RISC-V)
    li a7, 93         # sys_exit
    li a0, 0          # success code 0
    ecall

target_label:
    # Do minimal work and return immediately
    jr ra             # Jump register (return to back_from_target)
