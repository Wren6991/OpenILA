OpenILA: Internal Logic Analyser for FPGA
=========================================

Internal logic analysers (ILAs) allow signals inside of an FPGA to be sampled and plotted. They are typically implemented with the FPGA's internal programmable resources.

OpenILA losslessly compresses the sampled data and streams to an internal memory, which is expected to be implemented with FPGA BRAMs or TRAMs (block or tile memories). The samples are then retrieved through some form of serial interface, which is expected to have much lower bandwidth than the sampling frontend. As a result, data cannot be streamed out in real time, except at very low sampling rates.

The main goals are:

- Easy to integrate
	- Verilog 2001 with no dependencies
	- SRAM model supports inference on tools such as IceStorm and Vivado
	- Single file edit to insert vendor memory macros if needed
- Simple control interface
	- Generic byte-oriented serial
	- SPI, UART interfaces are included in this repo
	- Easy to implement more
	- Software provided to dump .vcd files for waveform viewers
- Low complexity and area
	- Use of compression reduces memory requirements
- High operating frequency and minimal setup timing

OpenILA drops into your project and puts waveforms on your screen with minimum effort. Drop the files in, instantiate in your top-level module, and wire out the serial interface.