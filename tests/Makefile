SIM ?= icarus
TOPLEVEL_LANG ?= verilog

# HDL sources
VERILOG_SOURCES += $(PWD)/../hdl/crc64_o8.v
VERILOG_SOURCES += $(PWD)/../hdl/lin_comm.v
VERILOG_SOURCES += $(PWD)/../hdl/lin_resp.v
VERILOG_SOURCES += $(PWD)/../hdl/lin_top.v

# Targets
all: lin

lin:
		rm -rf sim_build
		$(MAKE) sim MODULE=lin_test TOPLEVEL=lin_top

include $(shell cocotb-config --makefiles)/Makefile.simmake

