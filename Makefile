netlist=netlist
waveform=./waveform.wf
files=sdram_controller.v sdram_controller_testbench.v 3rdparty/sdr.v
netlist_compiler=iverilog -Wall -g2012 -I3rdparty -Dsg6a -Dden256Mb -Dx16 -DNO_ALWAYS_COMB -DSIMRESULT="\"$(waveform)\"" -DPERIODS=400000 -DDEBUG -o
netlist_executer=vvp
netlist_executer_params=-lxt2
waveform_viewer=gtkwave
logfile=logfile.txt


all: view_waveform

view_waveform: $(waveform)
	$(waveform_viewer) $(waveform)

$(waveform): $(netlist)
	$(netlist_executer) $(netlist) $(netlist_executer_params) > $(logfile)

$(netlist): $(files) Makefile
	$(netlist_compiler) $(netlist) $(files)
clean:
	rm $(netlist)
	rm $(waveform)
	rm $(logfile)