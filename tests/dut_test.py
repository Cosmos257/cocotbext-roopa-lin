import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge, ReadOnly, NextTimeStep
from cocotb_bus.drivers import BusDriver
from cocotb_bus.monitors import BusMonitor
from cocotb_coverage.coverage import CoverPoint, CoverCross, coverage_db
import random
import constraint

# -------------------------
# Scoreboard callback
# -------------------------
def sb_fn(actual_frame):
    global expected_frames
    expected = expected_frames.pop(0)
    assert actual_frame == expected, f"Scoreboard mismatch! Expected: {expected}, Got: {actual_frame}"

# -------------------------
# Coverage points
# -------------------------
@CoverPoint("lin.pid", xf=lambda pid, data: pid, bins=range(64))
@CoverPoint("lin.data", xf=lambda pid, data: data, bins=range(0, 2**16, 1024))
@CoverCross("lin.cross.pid_data", items=["lin.pid", "lin.data"])
def lin_cover(pid, data):
    pass

# -------------------------
# LIN Commander driver
# -------------------------
class LINCommanderDriver(BusDriver):
    _signals = ["start", "pid"]

    def __init__(self, dut, name, clk):
        super().__init__(dut, name, clk)
        self.clk = clk
        self.bus.start.value = 0

    async def send_header(self, pid_val):
        self.bus.pid.value = pid_val
        self.bus.start.value = 1
        await RisingEdge(self.clk)
        self.bus.start.value = 0
        await NextTimeStep()

# -------------------------
# LIN Responder driver
# -------------------------
class LINResponderDriver(BusDriver):
    _signals = ["data"]

    def __init__(self, dut, name, clk):
        super().__init__(dut, name, clk)
        self.clk = clk

    async def send_data(self, data_val):
        self.bus.data.value = data_val
        await RisingEdge(self.clk)
        await NextTimeStep()

# -------------------------
# LIN Monitor (captures full frame)
# -------------------------
class LINMonitor(BusMonitor):
    _signals = ["frame_header_out", "response_out", "comm_tx_done", "resp_tx_done"]

    async def _monitor_recv(self):
        while True:
            await RisingEdge(self.clock)
            await ReadOnly()
            if self.bus.resp_tx_done.value or self.bus.comm_tx_done.value:
                frame = (self.bus.frame_header_out.value.integer << 90) | self.bus.response_out.value.integer
                self._recv(frame)

# -------------------------
# Packet Generator (CRV)
# -------------------------
class PacketGenerator:
    def __init__(self):
        self.p = constraint.Problem()
        self.p.addVariable("pid", list(range(64)))
        self.p.addVariable("data", list(range(0, 2**16, 1024)))

    def solve(self):
        self.solutions = self.p.getSolutions()

    def get(self):
        return random.choice(self.solutions)

# -------------------------
# Main test
# -------------------------
@cocotb.test()
async def lin_top_test(dut):
    global expected_frames
    expected_frames = []

    # Reset
    dut.rstn.value = 0
    await Timer(10, "ns")
    dut.rstn.value = 1
    await RisingEdge(dut.sys_clk)

    # Instantiate drivers and monitor
    cmd_driver = LINCommanderDriver(dut, "commander", dut.sys_clk)
    resp_driver = LINResponderDriver(dut, "responder", dut.sys_clk)
    LINMonitor(dut, "lin_monitor", dut.sys_clk, callback=sb_fn)

    pkt_gen = PacketGenerator()
    pkt_gen.solve()

    # Generate and apply 20 test vectors
    for i in range(20):
        pkt = pkt_gen.get()
        pid_val = pkt["pid"]
        data_val = pkt["data"]
        expected_frame = (pid_val << 90) | data_val  # simplified concatenation
        expected_frames.append(expected_frame)

        # Functional coverage
        lin_cover(pid_val, data_val)

        # Send header
        await cmd_driver.send_header(pid_val)

        # Wait until commander finishes
        while not dut.comm_tx_done.value:
            await RisingEdge(dut.sys_clk)

        # Send responder data
        await resp_driver.send_data(data_val)

        # Wait until responder finishes
        while not dut.resp_tx_done.value:
            await RisingEdge(dut.sys_clk)

        await Timer(10, "ns")

    # Report coverage
    coverage_db.report_coverage(cocotb.log.info, bins=True)
    coverage_file = "./lin_coverage.xml"
    coverage_db.export_to_xml(filename=coverage_file)

