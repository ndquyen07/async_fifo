# Asynchronous FIFO

A dual-clock FIFO that passes data from a write clock domain to a read clock domain.

## Design

- Parameters: `DATA_WIDTH` (default 8), `ADDR_WIDTH` (default 4), `DEPTH = 2**ADDR_WIDTH`
- Gray-code read and write pointers, each crossing through a 2-flip-flop synchronizer
- Registered `full` and `empty` flags
- First-word fall-through read: when `empty = 0`, `rd_data` already shows the oldest word

## Run

```
mkdir -p sim
iverilog -o sim/async_fifo tb/tb_async_fifo.v rtl/async_fifo.v
vvp sim/async_fifo
```

## Tests

- T1: flag values after reset
- T2: write until full, one extra write is dropped
- T3: read until empty, data comes out in order
- T4: 1000 random writes and reads at the same time, checked against a reference queue

All tests pass with `ADDR_WIDTH` = 2 and 4, with `rclk` both slower and faster than `wclk`.

## Files

```
rtl/async_fifo.v     FIFO
tb/tb_async_fifo.v   Testbench
```