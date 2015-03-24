# Alcetronics M68K board #

A single board computer with:
  * CPU: MC68HC000P8 running @ 20MHz
  * RAM: 8Mb SRAM (no wait states)
  * ROM: 4Mb FLASH (no wait states)
  * System controller: CPDL XC9572-PC84 @ 40MHz
  * System peripherals controller: FPGA XC4010E-PG191
  * Pheripherals:
    * 2x 24bit configurable timers (in fpga)
    * Interrupt controller (in fpga)
    * 2x Expansion headers connected to fpga with:
      * 34x GPIO @ 5V
      * 5x GPIO @ 3.3V
      * 1x I2C controller
      * 1x Global clock pin
    * Cpu bus expansion header with 8-bit databus and 2 configurable chip selects
    * Serial USB FT245 (memory mapped via cpld)
    * RTC DS12887 (memory mapped via fpga)
    * 3x SPI controllers connected to:
      * ADC MCP3208 (spi via fpga)
      * MMC/SD card reader (spi mode via fpga)
      * Ethernet ENC28J60 (spi via fpga)



SVN contents at the moment:
  * Bootloader 0v2
  * Verilog code used in the board

Downloads:
  * Schematics

Future contents:
  * uClinux patches
  * m68k toolchain




# Videos made by me #

> http://www.youtube.com/watch?v=GJmPS3jMwD4

> http://www.youtube.com/watch?v=hgWZDSXkC58

> http://www.youtube.com/watch?v=mncS0ZLWKSY

# Blog #

http://mc68k.blogspot.com/