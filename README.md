# RELOC133

Relocates the Promise Ultra133 TX2 controller's DMA buffer from low (<640k) to high memory.
Since this is located adjacent to the EBDA, it moves that to high memory too. Enjoy your full 640 KB of free memory!

### Assembling
```
fasm reloc133.asm
```
### Using
Add the following line to your `fdconfig.sys` or equivalent:
```
INSTALL=C:\PATH\TO\RELOC133.COM
```
### Caveats
- This program is entirely experimental. It messes with the internal workings of your storage controller. Use at your own risk.
- Warm-booting (skipping the BIOS routines) will no longer work. In fact, this could be extremely dangerous.
- Updating the DMA pointers involves writing to shadow-RAM, which is a chipset-specific procedure. This program is written and tested to work with Intel 440BX (PIIX) chipsets only. It may happen to work on other chipsets too, I don't know (and don't particularly care).

### License
GPLv3.
