import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, ReadOnly, FallingEdge
import os
import random
from cocotb_coverage.coverage import CoverPoint, CoverCross, coverage_db


# DUT parity bits (for PID)
def compute_parity_bits(pid_bits):

    p0 = pid_bits[0] ^ pid_bits[1] ^ pid_bits[2] ^ pid_bits[4]
    p1 = ~(pid_bits[1] ^ pid_bits[3] ^ pid_bits[4] ^ pid_bits[5]) & 0x1
    return p0, p1


def compute_checksum(data_bytes):

    # Flatten bytes into a 64-bit integer
    data = 0
    for i, b in enumerate(data_bytes):
        for j in range(8):
            bit = (b >> j) & 1   # LSB-first
            data |= bit << (8 * i + j)

    crc_in = 0xFF

    d = [(data >> i) & 1 for i in range(64)]
    c = [(crc_in >> i) & 1 for i in range(8)]

    crc_out = [0] * 8
    crc_out[0] = c[0] ^ c[4] ^ c[7] ^ d[0] ^ d[6] ^ d[7] ^ d[8] ^ d[12] ^ d[14] ^ d[16] ^ d[18] ^ d[19] ^ d[21] ^ d[23] ^ d[28] ^ d[30] ^ d[31] ^ d[34] ^ d[35] ^ d[39] ^ d[40] ^ d[43] ^ d[45] ^ d[48] ^ d[49] ^ d[52] ^ d[53] ^ d[54] ^ d[56] ^ d[60] ^ d[63]
    crc_out[1] = c[0] ^ c[1] ^ c[4] ^ c[5] ^ c[7] ^ d[0] ^ d[1] ^ d[6] ^ d[9] ^ d[12] ^ d[13] ^ d[14] ^ d[15] ^ d[16] ^ d[17] ^ d[18] ^ d[20] ^ d[21] ^ d[22] ^ d[23] ^ d[24] ^ d[25] ^ d[28] ^ d[29] ^ d[30] ^ d[32] ^ d[34] ^ d[36] ^ d[38] ^ d[40] ^ d[41] ^ d[42] ^ d[43] ^ d[44] ^ d[45] ^ d[47] ^ d[48] ^ d[50] ^ d[52] ^ d[54] ^ d[55] ^ d[56] ^ d[57] ^ d[60] ^ d[61]
    crc_out[2] = c[1] ^ c[2] ^ c[4] ^ c[5] ^ c[6] ^ c[7] ^ d[0] ^ d[1] ^ d[2] ^ d[6] ^ d[8] ^ d[10] ^ d[12] ^ d[13] ^ d[15] ^ d[17] ^ d[22] ^ d[24] ^ d[25] ^ d[28] ^ d[29] ^ d[31] ^ d[33] ^ d[34] ^ d[36] ^ d[37] ^ d[38] ^ d[39] ^ d[41] ^ d[42] ^ d[46] ^ d[47] ^ d[50] ^ d[51] ^ d[55] ^ d[57] ^ d[58] ^ d[61] ^ d[62]
    crc_out[3] = c[2] ^ c[3] ^ c[5] ^ c[6] ^ c[7] ^ d[1] ^ d[2] ^ d[3] ^ d[7] ^ d[9] ^ d[11] ^ d[13] ^ d[14] ^ d[16] ^ d[18] ^ d[23] ^ d[25] ^ d[26] ^ d[29] ^ d[30] ^ d[34] ^ d[35] ^ d[36] ^ d[37] ^ d[38] ^ d[39] ^ d[40] ^ d[42] ^ d[43] ^ d[45] ^ d[47] ^ d[48] ^ d[49] ^ d[51] ^ d[52] ^ d[56] ^ d[58] ^ d[59] ^ d[62] ^ d[63]
    crc_out[4] = c[0] ^ c[3] ^ c[4] ^ c[6] ^ c[7] ^ d[2] ^ d[3] ^ d[4] ^ d[8] ^ d[10] ^ d[12] ^ d[14] ^ d[15] ^ d[17] ^ d[19] ^ d[24] ^ d[26] ^ d[27] ^ d[30] ^ d[31] ^ d[35] ^ d[36] ^ d[37] ^ d[38] ^ d[39] ^ d[40] ^ d[41] ^ d[43] ^ d[44] ^ d[46] ^ d[48] ^ d[49] ^ d[50] ^ d[52] ^ d[53] ^ d[57] ^ d[59] ^ d[60] ^ d[63]
    crc_out[5] = c[1] ^ c[4] ^ c[5] ^ c[7] ^ d[3] ^ d[4] ^ d[5] ^ d[9] ^ d[11] ^ d[13] ^ d[15] ^ d[16] ^ d[18] ^ d[20] ^ d[25] ^ d[27] ^ d[28] ^ d[31] ^ d[32] ^ d[36] ^ d[37] ^ d[38] ^ d[39] ^ d[40] ^ d[41] ^ d[42] ^ d[44] ^ d[45] ^ d[47] ^ d[49] ^ d[50] ^ d[51] ^ d[53] ^ d[54] ^ d[58] ^ d[60] ^ d[61]
    crc_out[6] = c[2] ^ c[5] ^ c[6] ^ d[4] ^ d[5] ^ d[6] ^ d[10] ^ d[12] ^ d[14] ^ d[16] ^ d[17] ^ d[19] ^ d[21] ^ d[26] ^ d[28] ^ d[29] ^ d[32] ^ d[33] ^ d[37] ^ d[38] ^ d[39] ^ d[40] ^ d[41] ^ d[42] ^ d[43] ^ d[45] ^ d[46] ^ d[48] ^ d[50] ^ d[51] ^ d[52] ^ d[54] ^ d[55] ^ d[59] ^ d[61] ^ d[62]
    crc_out[7] = c[3] ^ c[6] ^ c[7] ^ d[5] ^ d[6] ^ d[7] ^ d[11] ^ d[13] ^ d[15] ^ d[17] ^ d[18] ^ d[20] ^ d[22] ^ d[27] ^ d[29] ^ d[30] ^ d[33] ^ d[34] ^ d[38] ^ d[39] ^ d[40] ^ d[41] ^ d[42] ^ d[43] ^ d[44] ^ d[46] ^ d[47] ^ d[49] ^ d[51] ^ d[52] ^ d[53] ^ d[55] ^ d[56] ^ d[60] ^ d[62] ^ d[63]

    
    # Pack result (LSB-first)
    checksum = sum((crc_out[i] & 1) << i for i in range(8))
    return checksum
def build_expected_header(pid):

    # Break
    break_field = [0] * 13

    # Delimiter
    delimiter = [1]

    # Sync field
    sync_bits = [0] + [int(x) for x in f"{0x55:08b}"[::-1]] + [1]

    # PID field
    pid_bits = [(pid >> i) & 1 for i in range(6)]
    p0, p1 = compute_parity_bits(pid_bits)
    pid_full = pid_bits + [p0, p1]
    pid_field = [0] + pid_full + [1]

    header_bits = break_field + delimiter + sync_bits + pid_field

    # Convert to int
    header_value = 0
    for bit in header_bits:
        header_value = (header_value << 1) | bit

    return header_value, header_bits


def build_expected_response(data_bytes):

    response_bits = []

    # Data bytes
    for byte in data_bytes:
        bits = [0]  # start
        bits += [int(x) for x in f"{byte:08b}"[::-1]]  # LSB-first
        bits += [1]  # stop
        response_bits.extend(bits)

    # Checksum
    checksum = compute_checksum(data_bytes)
    checksum_bits = [0] + [int(x) for x in f"{checksum:08b}"[::-1]] + [1]
    response_bits.extend(checksum_bits)

    # Convert to int
    response_value = 0
    for bit in response_bits:
        response_value = (response_value << 1) | bit

    return response_value, response_bits


@CoverPoint("top.prot.lin.current",  xf=lambda t: t["current"],  bins=["Idle","HeaderTx","ResponseTx"])
@CoverPoint("top.prot.lin.previous", xf=lambda t: t["previous"], bins=["Idle","HeaderTx","ResponseTx"])
@CoverCross("top.prot.lin.cross", items=["top.prot.lin.previous","top.prot.lin.current"])

def protocol_cover(t):
    pass

# PID coverage
@CoverPoint("top.lin.pid",
            xf=lambda pid: "low" if pid < 21 else ("medium" if pid < 42 else "high"),
            bins=["low", "medium", "high"])
def cover_pid(pid):
    pass

# Data byte coverage
@CoverPoint("top.lin.data_byte",
            xf=lambda b: "low" if b < 85 else ("medium" if b < 170 else "high"),
            bins=["low", "medium", "high"])
def cover_data_byte(b):
    pass

# Data length coverage
@CoverPoint("top.lin.data_len",
            xf=lambda length: length,
            bins=list(range(1, 9)))
def cover_data_len(length):
    pass

async def protocol_monitor(dut):
    prev = "Idle"
    # Reset completion
    while int(dut.rstn.value) == 0:
        await RisingEdge(dut.sys_clk)
    while True:
        # HEADER phase
        await RisingEdge(dut.comm_tx_done)
        txn = {"previous": prev, "current": "HeaderTx"}
        protocol_cover(txn)
        prev = "HeaderTx"

        # RESPONSE phase
        await RisingEdge(dut.resp_tx_done)
        txn = {"previous": prev, "current": "ResponseTx"}
        protocol_cover(txn)
        prev = "ResponseTx"

        # Idle

        await FallingEdge(dut.resp_tx_done)
        txn = {"previous": prev, "current": "Idle"}
        protocol_cover(txn)
        prev = "Idle"



@cocotb.test()

async def lin_top_test(dut):

    # Reset DUT
    dut.rstn.value = 1
    await Timer(1, units="ns")
    dut.rstn.value = 0
    await Timer(1, "ns")
    await RisingEdge(dut.sys_clk)
    dut.rstn.value = 1

    cocotb.start_soon(protocol_monitor(dut))
    #CRV
    for i in range(30):
        cocotb.log.info(f"\n===== Transaction {i+1}/20 =====")

        # Generate random PID (6-bit field in LIN: 0–63)
        pid = random.randint(0, 0x3F)

        # Generate 1–8 random data bytes (each 0–255)
        data_length = random.randint(1, 8)
        data_bytes = [random.randint(0, 0xFF) for _ in range(data_length)]

        cover_pid(pid)
        cover_data_len(data_length)
        for b in data_bytes:
            cover_data_byte(b)

        # Pad with zeros so total is always 8 bytes DUT works like this
        padded_data = data_bytes + [0] * (8 - len(data_bytes))

        cocotb.log.info(
            f"[INPUT] PID = {pid:#04x}, Data = {[hex(b) for b in data_bytes]} "
            f"(padded: {[hex(b) for b in padded_data]})"
        )

        # Drive values to DUT
        dut.pid.value = pid
        dut.data.value = int.from_bytes(bytes(padded_data), "little")

        await RisingEdge(dut.sys_clk)

        # Wait for commander to finish
        await RisingEdge(dut.comm_tx_done)
        await ReadOnly()

        actual_header = int(dut.frame_header_out.value)
        expected_header, _ = build_expected_header(pid)

        cocotb.log.info(f"[HEADER] Expected: 0x{expected_header:X}")
        cocotb.log.info(f"[HEADER] Actual:   0x{actual_header:X}")

        assert actual_header == expected_header, \
            f"Header mismatch (Transaction {i+1}): {hex(actual_header)} != {hex(expected_header)}"

        # Wait for responder to finish
        await RisingEdge(dut.resp_tx_done)
        await ReadOnly()

        actual_response = int(dut.response_out.value)
        expected_response, _ = build_expected_response(padded_data)

        cocotb.log.info(f"[RESPONSE] Expected: 0x{expected_response:X}")
        cocotb.log.info(f"[RESPONSE] Actual:   0x{actual_response:X}")

        assert actual_response == expected_response, \
            f"Response mismatch (Transaction {i+1}): {hex(actual_response)} != {hex(expected_response)}"

        #Delay before next transaction
        await Timer(50, "ns")
    coverage_db.report_coverage(cocotb.log.info, bins = True)
    coverage_file=os.path.join(os.getenv("RESULT_PATH","./"),"coverage.xml")
    coverage_db.export_to_xml(filename=coverage_file)

