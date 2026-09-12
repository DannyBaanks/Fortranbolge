# Fortranbolge

Staging de un intérprete Classic Malbolge en GNU Fortran. El objetivo es
reproducir el gate canónico (`Hello, world.`, 48 pasos, estado final
`a=19758,c=85,d=63`) con I/O de bytes mediante un shim C mínimo.

Build local:

```powershell
gfortran -O2 -std=f2008 -o fortranbolge.exe src\fortranbolge.f90 c\io_shim.c
```

Estado: implementación inicial; debe pasar el gate antes de exportarse.
