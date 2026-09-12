program fortranbolge
    use iso_fortran_env, only: int8, int32, int64, error_unit
    use iso_c_binding, only: c_int
    implicit none

    integer(int64), parameter :: mem_size = 59049_int64, last_pos = 59048_int64
    integer(int64), parameter :: block_size = 243_int64, pow9 = 19683_int64
    integer(int64) :: a_reg, c_reg, d_reg, steps, max_steps, input_pos
    integer(int64) :: fill_start, chain_until, out_len, n_cells
    integer(int64), allocatable :: overlay(:), chain(:), cells(:), input_data(:), output_data(:)
    logical, allocatable :: present(:)
    character(len=1024) :: program_path, arg
    integer :: argc, arg_status, max_len, ios, unit_no, i, raw_size
    integer(int8), allocatable :: raw(:)
    character(len=32) :: halt_reason
    character(len=7) :: status
    logical :: halted

    interface
        subroutine fb_putc(value) bind(C, name="fb_putc")
            import c_int
            integer(c_int), value :: value
        end subroutine fb_putc
        subroutine fb_flush() bind(C, name="fb_flush")
        end subroutine fb_flush
    end interface

    argc = command_argument_count()
    if (argc < 1) then
        write(error_unit, '(A)') 'usage: fortranbolge <program.mal> [max_steps]'
        stop 1
    end if
    call get_command_argument(1, program_path)
    max_steps = 100000000_int64
    if (argc >= 2) then
        call get_command_argument(2, arg, max_len, arg_status)
        read(arg(1:max_len), *, iostat=ios) max_steps
        if (ios /= 0 .or. max_steps < 1) max_steps = 100000000_int64
    end if

    inquire(file=trim(program_path), size=raw_size, iostat=ios)
    if (ios /= 0 .or. raw_size < 1) then
        write(error_unit, '(A)') 'error: cannot open program'
        stop 2
    end if
    allocate(raw(raw_size))
    open(newunit=unit_no, file=trim(program_path), access='stream', form='unformatted', &
         status='old', iostat=ios)
    if (ios /= 0) stop 2
    read(unit_no, iostat=ios) raw
    close(unit_no)
    if (ios /= 0) stop 2

    allocate(cells(mem_size))
    n_cells = 0
    do i = 1, raw_size
        if (iand(int(raw(i), int32), 255_int32) == 10 .or. &
            iand(int(raw(i), int32), 255_int32) == 13 .or. &
            iand(int(raw(i), int32), 255_int32) == 32 .or. &
            iand(int(raw(i), int32), 255_int32) == 9) cycle
        if (iand(int(raw(i), int32), 255_int32) < 33 .or. &
            iand(int(raw(i), int32), 255_int32) > 126 .or. n_cells >= mem_size) then
            write(error_unit, '(A)') 'error: invalid character in program'
            stop 2
        end if
        n_cells = n_cells + 1
        cells(n_cells) = int(iand(int(raw(i), int32), 255_int32), int64)
    end do
    if (n_cells == 0) stop 2

    allocate(overlay(mem_size), chain(mem_size), present(mem_size))
    overlay = 0; chain = 0; present = .false.
    do i = 1, n_cells
        overlay(i) = cells(i); present(i) = .true.
    end do
    fill_start = max(2_int64, n_cells); chain_until = fill_start
    a_reg = 0; c_reg = 0; d_reg = 0; steps = 0; input_pos = 0; out_len = 0
    allocate(input_data(1000000), output_data(65536)); input_data = 0; output_data = 0
    do i = 1, size(input_data)
        read(5, iostat=ios) input_data(i)
        if (ios /= 0) exit
        input_data(i) = iand(input_data(i), 255_int64)
    end do
    input_pos = i - 1
    halted = .false.; halt_reason = 'StepsExhausted'

    do while (.not. halted .and. steps < max_steps)
        steps = steps + 1
        call execute_step()
    end do
    if (.not. halted) halt_reason = 'StepsExhausted'

    do i = 1, out_len
        call fb_putc(int(output_data(i), c_int))
    end do
    if (out_len > 0) call fb_putc(10_c_int)
    call fb_flush()
    if (halt_reason == 'StepsExhausted') then
        status = 'TIMEOUT'
    else
        status = 'HALTED'
    end if
    write(error_unit, '(A,I0,A,I0,A,I0,A,A,A,I0,A,A,A,I0,A)') &
        '{"final":{"a":', a_reg, ',"c":', c_reg, ',"d":', d_reg, &
        '},"halt_reason":"', trim(halt_reason), '","output_len":', out_len, &
        ',"status":"', trim(status), &
        '","steps":', steps, '}'

contains

    integer(int64) function crazy5(x, y)
        integer(int64), intent(in) :: x, y
        integer(int64), parameter :: table(3,3) = reshape([1,1,2,0,0,2,0,2,1], [3,3])
        integer(int64) :: xx, yy, place, k
        xx=x; yy=y; place=1; crazy5=0
        do k=1,5
            crazy5 = crazy5 + table(mod(yy,3_int64)+1, mod(xx,3_int64)+1)*place
            xx=xx/3_int64; yy=yy/3_int64; place=place*3_int64
        end do
    end function crazy5

    integer(int64) function crazy(x, y)
        integer(int64), intent(in) :: x, y
        crazy = crazy5(mod(x,block_size),mod(y,block_size)) + &
                block_size*crazy5(x/block_size,y/block_size)
    end function crazy

    integer(int64) function rotate(x)
        integer(int64), intent(in) :: x
        rotate = pow9*mod(x,3_int64) + x/3_int64
    end function rotate

    recursive subroutine mem_get(address, value)
        integer(int64), intent(in) :: address
        integer(int64), intent(out) :: value
        integer(int64) :: index
        index = address + 1
        if (present(index)) then
            value = overlay(index); return
        end if
        if (address < fill_start) then
            value = 0; return
        end if
        if (address >= chain_until) call ensure_filled(address)
        value = chain(index)
    end subroutine mem_get

    subroutine mem_set(address, value)
        integer(int64), intent(in) :: address, value
        present(address+1)=.true.; overlay(address+1)=value
    end subroutine mem_set

    subroutine ensure_filled(address)
        integer(int64), intent(in) :: address
        integer(int64) :: block_end, tail_end, j, p1, p2, v1, v2, nxt
        block_end=(address/block_size+1)*block_size
        tail_end=(fill_start/block_size+1)*block_size
        if (chain_until == fill_start) then
            p1=0; p2=0
            if (fill_start > 0 .and. present(fill_start)) p1=overlay(fill_start)
            if (fill_start > 1 .and. present(fill_start-1)) p2=overlay(fill_start-1)
            j=fill_start
        else
            j=chain_until; p1=chain(j); p2=chain(j-1)
        end if
        do while (j < block_end .and. j < mem_size)
            if (j == tail_end) then
                call mem_get(j-1,v1); call mem_get(j-2,v2); nxt=crazy(v1,v2)
            else if (j == tail_end+1) then
                call mem_get(j-2,v2); nxt=crazy(p1,v2)
            else
                nxt=crazy(p1,p2)
            end if
            chain(j+1)=nxt; p2=p1; p1=nxt; j=j+1
        end do
        chain_until=min(block_end,mem_size)
    end subroutine ensure_filled

    subroutine execute_step()
        integer(int64) :: ins, v, value, current, r
        call mem_get(c_reg,ins)
        if (ins < 33 .or. ins > 126) then
            halted=.true.; halt_reason='InvalidCell'; return
        end if
        v=mod(ins+c_reg,94_int64)
        select case(v)
        case(4); call mem_get(d_reg,c_reg)
        case(5)
            if (out_len < size(output_data)) then
                out_len=out_len+1; output_data(out_len)=mod(a_reg,256_int64)
            end if
        case(23)
            if (input_pos >= i-1) then
                halted=.true.; halt_reason='Eof'; return
            end if
            input_pos=input_pos+1; a_reg=input_data(input_pos)
        case(39)
            call mem_get(d_reg,value); r=rotate(value); call mem_set(d_reg,r); a_reg=r
        case(40); call mem_get(d_reg,d_reg)
        case(62)
            call mem_get(d_reg,value); r=crazy(a_reg,value); call mem_set(d_reg,r); a_reg=r
        case(81); halted=.true.; halt_reason='VInstruction'; return
        end select
        call mem_get(c_reg,current)
        if (current >= 33 .and. current <= 126) call mem_set(c_reg,enc_value(current))
        c_reg=merge(0_int64,c_reg+1,c_reg==last_pos)
        d_reg=merge(0_int64,d_reg+1,d_reg==last_pos)
    end subroutine execute_step

    integer(int64) function enc_value(value)
        integer(int64), intent(in) :: value
        character(len=94), parameter :: encryption = &
            '5z]&gqtyfr$(we4{WP)H-Zn,[%\3dL+Q;>U!pJS72FhOA1CB6v^=I_0/8|jsb9m<.TVac`uY*MK''X~xDl}REokN:#?G"i@'
        enc_value=iachar(encryption(value-32:value-32))
    end function enc_value
end program fortranbolge
