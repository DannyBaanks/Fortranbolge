# Fortranbolge

Intérpretes de Malbolge Classic y Unshackled (3^19) implementados en GNU Fortran con un shim C mínimo para I/O binario.

## Compilación

### Linux (gfortran + gcc)

```bash
gfortran -O2 -std=f2008 -o fortranbolge src/fortranbolge.f90 c/io_shim.c
gfortran -O2 -std=f2008 -o fortranbolge19 src/fortranbolge19.f90 c/io_shim.c
```

### Windows (MSYS2)

```powershell
gfortran -O2 -std=f2008 -o fortranbolge.exe src\fortranbolge.f90 c\io_shim.c
gfortran -O2 -std=f2008 -o fortranbolge19.exe src\fortranbolge19.f90 c\io_shim.c
```

## Ejecución

### Classic (59,049 celdas)

```bash
./fortranbolge fixture.mal 100 < /dev/null
```

Salida esperada:
```text
stdout: Hello, world.
stderr: {"final":{"a":19758,"c":85,"d":63},"halt_reason":"VInstruction","output_len":13,"status":"HALTED","steps":48}
```

### Unshackled (3^19 celdas)

```bash
./fortranbolge19 fixture19.mal 10 < /dev/null
```

Salida:
```json
{"final":{"a":1162261466,"c":2,"d":2},"halt_reason":"HaltOpcode","status":"HALTED","steps":3,"materialized_chain":0}
```

## Pruebas automatizadas

```bash
./tests/run_tests.sh
```
