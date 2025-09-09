SIM ?= icarus
TOPLEVEL_LANG ?= verilog
VERILOG_SOURCES += $(PWD)/../hdl/crcd64_o8.v
VERILOG_SOURCES += $(PWD)/../hdl/lin_comm.v
VERILOG_SOURCES += $(PWD)/../hdl/lin_resp.v
VERILOG_SOURCES += $(PWD)/../hdl/lin_top.v
VERILOG_SOURCES += $(PWD)/../hdl/lin_top_wrapper.v
TOPLEVEL = lin_top_wrapper
MODULE = lin_top_test

lin:
	rm -rf sim_build
	$(MAKE) sim MODULE=$(MODULE) TOPLEVEL=$(TOPLEVEL)

include $(shell cocotb-config --makefiles)/Makefile.sim

