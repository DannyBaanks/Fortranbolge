# Fortranbolge 1.0-gate

Intérprete independiente de Classic Malbolge implementado en GNU Fortran,
con un shim C mínimo para I/O de bytes. Esta versión está verificada contra el
gate Classic; no se presenta todavía como paridad completa con
MalbolgeEngineCPP.

## Build

```powershell
gfortran -O2 -std=f2008 -o fortranbolge.exe src\fortranbolge.f90 c\io_shim.c
```

## Run

```powershell
cmd /c "type nul | fortranbolge.exe fixture.mal 100 1>out.bin 2>report.txt"
```

The program reads a Malbolge source file and an optional maximum step count.
Program output is raw bytes on stdout with one framing LF; the machine report
is compact JSON on stderr.

## Verified gate

Observed result from `fixture.mal`:

```text
stdout: 48 65 6c 6c 6f 2c 20 77 6f 72 6c 64 2e 0a
stderr: {"final":{"a":19758,"c":85,"d":63},"halt_reason":"VInstruction","output_len":13,"status":"HALTED","steps":48}
```

This demonstrates `Hello, world.`, 48 executed steps, and the canonical final
register values.

## Demonstrated / pending

| Capability | Status |
|---|---|
| Classic execution core | DEMONSTRATED |
| Byte-oriented stdout framing | DEMONSTRATED |
| Canonical 48-step gate | DEMONSTRATED |
| Compact JSON report | DEMONSTRATED |
| Snapshots and resume | NOT_IMPLEMENTED |
| Instruction tracing | NOT_IMPLEMENTED |
| Embeddable library API | NOT_IMPLEMENTED |
| Broad differential corpus | NOT_DEMONSTRATED |
| Fuzzing and benchmarks | NOT_DEMONSTRATED |

## Scope

`1.0-gate` means the verified Classic fixture and execution contract are
working. Input-path hardening, portable Fortran aliasing cleanup, snapshots,
tracing, fuzzing, benchmarks, and broader differential evidence remain future
work.
