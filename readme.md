# Armleo's SDRAM Controller
```
            +-------+
            |       |
-> clk ->   | PLL   |  ->  clk 1.5ns shifted -> to sdram avalon clk
            |       |  ->  clk shifted 90 degrees (without 1.5ns) -> to sdram clk
            |       |
            |       |
            +-------+
```


Address bus is symbol-based (8 bit = 1 value increment on address bus).
Host must support waitrequest (non-inverted), readdatavalid.
Host sets address on first clock without waitrequest and waits for readdatavalid.
Host must give a avalon bus clock (clk signal) and (clk_90_degrees) which is avalon clk signal shifted by 90 degrees accounting delay of output pin.
This controller implements Avalon MM bus interface.
It refreshes memory with autorefresh in between any transfers.
This controller supports burst transactions and is highly configurable on any level from column, row, bank sizes. This controller does not support multiple chips with chipselect, but can be made so with a little modifications.
Theoretical speed is about 99% of bus width multiplied to clock speed.
This controller does not close any bank< allowing multiple low latency accesses to same row until refresh is requested by internal finite state machine.
sdram_* connects to sdram pins and dbus (short from databus) is Avalon-MM bus.

# 3rd party
3rdparty folder contains all third party sources (SDR SDRAM Model by Micron, Datasheet to SDRAM and avalon interface specification from Altera). 