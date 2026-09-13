program fortranbolge19
  use iso_fortran_env, only: int8, int32, int64, error_unit
  use iso_c_binding, only: c_int
  implicit none

  integer(int64), parameter :: memory_size = 1162261467_int64 ! 3^19
  integer(int64), parameter :: third = 387420489_int64 ! 3^18
  integer(int64), parameter :: eof_value = memory_size - 1_int64
  integer(int64), parameter :: valid_ops(8) = [4_int64, 5_int64, 23_int64, &
       39_int64, 40_int64, 62_int64, 68_int64, 81_int64]

  integer(int64), allocatable :: image(:), chain(:), overlay_address(:), overlay_value(:)
  integer(int64) :: image_length, chain_length, overlay_length
  integer(int64) :: a_reg, c_reg, d_reg, steps, max_steps
  integer(int64) :: input_byte, instruction, current, value, target_d
  integer :: argc, ios, unit_no, raw_size, i, n
  character(len=1024) :: program_path, argument
  character(len=32) :: halt_reason
  character(len=8) :: status
  integer(int8), allocatable :: raw(:)
  logical :: halted

  interface
     subroutine fb_putc(value) bind(C, name="fb_putc")
       import c_int
       integer(c_int), value :: value
     end subroutine fb_putc
     subroutine fb_flush() bind(C, name="fb_flush")
     end subroutine fb_flush
     integer(c_int) function fb_getc() bind(C, name="fb_getc")
       import c_int
     end function fb_getc
  end interface

  argc = command_argument_count()
  if (argc < 1) then
     write(error_unit, '(A)') 'usage: fortranbolge19 <program.mal> [max_steps]'
     stop 1
  end if
  call get_command_argument(1, program_path)
  max_steps = 2000000_int64
  if (argc >= 2) then
     call get_command_argument(2, argument)
     read(argument, *, iostat=ios) max_steps
     if (ios /= 0 .or. max_steps < 1) max_steps = 2000000_int64
  end if

  inquire(file=trim(program_path), size=raw_size, iostat=ios)
  if (ios /= 0 .or. raw_size < 1) then
     write(error_unit, '(A)') 'error: cannot open program'
     stop 2
  end if
  allocate(raw(raw_size))
  open(newunit=unit_no, file=trim(program_path), access='stream', form='unformatted', &
       status='old', action='read', iostat=ios)
  if (ios /= 0) stop 2
  read(unit_no, iostat=ios) raw
  close(unit_no)
  if (ios /= 0) stop 2

  allocate(image(max(1, raw_size)))
  image_length = 0
  do i = 1, raw_size
     n = iand(int(raw(i), int32), 255_int32)
     if (n == 10 .or. n == 13 .or. n == 32 .or. n == 9) cycle
     if (n < 33 .or. n > 126 .or. image_length >= memory_size) then
        write(error_unit, '(A,I0)') 'error: invalid program character at ', image_length
        stop 2
     end if
     image_length = image_length + 1
     if (image_length > size(image, kind=int64)) call grow_image(image_length)
     image(image_length) = n
  end do
  if (image_length == 0) then
     write(error_unit, '(A)') 'error: empty program'
     stop 2
  end if

  do i = 1, int(image_length)
     if (.not. valid_opcode(decode(image(i), int(i-1, int64)))) then
        write(error_unit, '(A,I0)') 'error: invalid opcode at ', i-1
        stop 2
     end if
  end do
  allocate(chain(1), overlay_address(1), overlay_value(1))
  chain_length = 0; overlay_length = 0
  a_reg = 0; c_reg = 0; d_reg = 0; steps = 0
  halted = .false.; halt_reason = 'StepsExhausted'

  do while (.not. halted .and. steps < max_steps)
     steps = steps + 1
     call mem_get(c_reg, instruction)
     instruction = decode(instruction, c_reg)
     select case (instruction)
     case (4_int64)
        call mem_get(d_reg, c_reg)
     case (5_int64)
        call fb_putc(int(modulo(a_reg, 256_int64), c_int))
     case (23_int64)
        input_byte = fb_getc()
        if (input_byte < 0) then
           a_reg = eof_value
        else
           a_reg = input_byte
        end if
     case (39_int64)
        call mem_get(d_reg, value)
        value = rotate19(value)
        call mem_set(d_reg, value); a_reg = value
     case (40_int64)
        call mem_get(d_reg, target_d); d_reg = target_d
     case (62_int64)
        call mem_get(d_reg, value)
        value = crazy19(a_reg, value)
        call mem_set(d_reg, value); a_reg = value
     case (81_int64)
        halted = .true.; halt_reason = 'HaltOpcode'
     case default
        ! 68 and all non-instruction residues are no-ops.
     end select
     if (halted) exit

     call mem_get(c_reg, current)
     if (current >= 33 .and. current <= 126) call mem_set(c_reg, encrypt(current))
     c_reg = modulo(c_reg + 1_int64, memory_size)
     d_reg = modulo(d_reg + 1_int64, memory_size)
  end do
  if (.not. halted) halt_reason = 'MaxSteps'
  call fb_flush()
  if (halted) then; status = 'HALTED'; else; status = 'TIMEOUT'; end if
  write(error_unit, '(A,I0,A,I0,A,I0,A,A,A,A,A,I0,A,I0,A)') &
       '{"final":{"a":', a_reg, ',"c":', c_reg, ',"d":', d_reg, &
       '},"halt_reason":"', trim(halt_reason), '","status":"', trim(status), &
       '","steps":', steps, ',"materialized_chain":', chain_length, '}'

contains

  integer(int64) function region(position)
    integer(int64), intent(in) :: position
    region = position / third
  end function region

  integer(int64) function offset(position)
    integer(int64), intent(in) :: position
    integer(int64) :: a1, a2
    a1 = 94_int64 - modulo((memory_size - 1_int64) / 6_int64 - 29524_int64, 94_int64)
    a2 = 94_int64 - modulo((memory_size - 1_int64) / 3_int64 - 59048_int64, 94_int64)
    select case (region(position))
    case (0); offset = 0
    case (1); offset = modulo(a1 - third, 94_int64) + 94_int64
    case default; offset = a2 - modulo(2_int64 * third, 94_int64) + 94_int64
    end select
  end function offset

  integer(int64) function decode(cell, position)
    integer(int64), intent(in) :: cell, position
    decode = modulo(cell + position + offset(position), 94_int64)
  end function decode

  logical function valid_opcode(op)
    integer(int64), intent(in) :: op
    valid_opcode = any(valid_ops == op)
  end function valid_opcode

  integer(int64) function crazy19(x, y)
    integer(int64), intent(in) :: x, y
    integer(int64), parameter :: table(3,3) = reshape([1_int64,1_int64,2_int64, &
         0_int64,0_int64,2_int64, 0_int64,2_int64,1_int64], [3,3])
    integer(int64) :: xx, yy, place, k
    xx = x; yy = y; place = 1; crazy19 = 0
    do k = 1, 19
       crazy19 = crazy19 + table(modulo(yy,3_int64)+1, modulo(xx,3_int64)+1) * place
       xx = xx / 3_int64; yy = yy / 3_int64; place = place * 3_int64
    end do
  end function crazy19

  integer(int64) function rotate19(x)
    integer(int64), intent(in) :: x
    integer(int64) :: lower, trit, rest
    lower = modulo(x, third); trit = modulo(lower, 3_int64); rest = lower / 3_int64
    rotate19 = (x - lower) + rest + trit * (third / 3_int64)
  end function rotate19

  subroutine grow_image(want)
    integer(int64), intent(in) :: want
    integer(int64), allocatable :: replacement(:)
    integer(int64) :: new_size
    new_size = max(want, 2_int64 * size(image, kind=int64))
    allocate(replacement(new_size)); replacement = 0
    replacement(1:image_length) = image(1:image_length)
    call move_alloc(replacement, image)
  end subroutine grow_image

  subroutine ensure_chain(address)
    integer(int64), intent(in) :: address
    integer(int64), allocatable :: replacement(:)
    integer(int64) :: want, new_size, j, previous, before
    if (address < image_length) return
    want = address - image_length + 1_int64
    if (want > size(chain, kind=int64)) then
       new_size = max(want, max(1_int64, 2_int64 * size(chain, kind=int64)))
       allocate(replacement(new_size)); replacement = 0
       if (chain_length > 0) replacement(1:chain_length) = chain(1:chain_length)
       call move_alloc(replacement, chain)
    end if
    if (chain_length == 0) then
       previous = image(image_length)
       if (image_length > 1) then; before = image(image_length-1); else; before = 0; end if
    else
       previous = chain(chain_length)
       if (chain_length > 1) then; before = chain(chain_length-1); else; before = image(image_length); end if
    end if
    do j = chain_length + 1, want
       value = crazy19(previous, before)
       chain(j) = value; before = previous; previous = value
    end do
    chain_length = want
  end subroutine ensure_chain

  subroutine mem_get(address, result)
    integer(int64), intent(in) :: address
    integer(int64), intent(out) :: result
    integer(int64) :: j
    do j = 1, overlay_length
       if (overlay_address(j) == address) then; result = overlay_value(j); return; end if
    end do
    if (address < image_length) then
       result = image(address+1); return
    end if
    call ensure_chain(address)
    result = chain(address - image_length + 1)
  end subroutine mem_get

  subroutine mem_set(address, new_value)
    integer(int64), intent(in) :: address, new_value
    integer(int64), allocatable :: oa(:), ov(:)
    integer(int64) :: j, new_size
    if (address < image_length) then; image(address+1) = new_value; return; end if
    do j = 1, overlay_length
       if (overlay_address(j) == address) then; overlay_value(j) = new_value; return; end if
    end do
    if (overlay_length == size(overlay_address, kind=int64)) then
       new_size = max(1_int64, 2_int64 * size(overlay_address, kind=int64))
       allocate(oa(new_size), ov(new_size)); oa = 0; ov = 0
       if (overlay_length > 0) then
          oa(1:overlay_length) = overlay_address(1:overlay_length)
          ov(1:overlay_length) = overlay_value(1:overlay_length)
       end if
       call move_alloc(oa, overlay_address); call move_alloc(ov, overlay_value)
    end if
    overlay_length = overlay_length + 1; overlay_address(overlay_length)=address; overlay_value(overlay_length)=new_value
  end subroutine mem_set

  integer(int64) function encrypt(cell)
    integer(int64), intent(in) :: cell
    ! Printable values use only the exact 141-byte XLAT at indices 33..126.
    character(len=141), parameter :: xlat = &
         'SOMEBODY MAKE ME FEEL ALIVE' // &
         '[hj9>,5z]&gqtyfr$(we4{WP)H-Zn,[%\3dL+Q;>U!pJS72FhOA1CB6v^=I_0/8|jsb9m<.TVac`uY*MK''X~xDl}REokN:#?G"i@' // &
         'AND SHATTER ME'
    encrypt = iachar(xlat(int(cell+1):int(cell+1)))
  end function encrypt

end program fortranbolge19
