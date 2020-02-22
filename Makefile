netlist=netlist
simresult=./waveform.lxt2
vvpparams=-lxt2
iverilog=iverilog
files=sdram_controller.v sdram_controller_testbench.v 3rdparty/sdr.v
vvp=vvp
gtkwave=gtkwave

build: $(netlist)
	
execute: $(simresult)
	
view: $(simresult)
	$(gtkwave) $(simresult)

$(simresult): $(netlist)
	$(vvp) $(netlist) -lxt2 > logfile.txt
$(netlist): $(files) Makefile
	$(iverilog) -g2012  -o $(netlist) -DSIMRESULT="\"$(simresult)\"" -DDEBUG  -DPERIODS=101000 -I3rdparty $(files) >> logfile.txt
clean:
	rm -f $(simresult)
	rm -f $(netlist)
	rm -f logfile.txt
	