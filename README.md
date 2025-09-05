# LIN Protocol Testbench (Cocotb)

This repository contains a **Cocotb-based verification testbench** for the **Local Interconnect Network (LIN) protocol**.  
The testbench verifies the behavior of a DUT implementing LIN communication by generating header frames, response frames, and validating protocol compliance through constrained random tests, functional coverage, and monitors.

---

## 📌 Overview

The LIN protocol is a low-cost, single-wire communication standard used in automotive and embedded systems. It supports communication between a **master node** (commander) and multiple **slave nodes** (responders).

A LIN frame consists of two main parts:

- **LIN Header** (sent by master)  
- **LIN Response** (sent by slave)

---

## 🔹 LIN Frame Structure

### LIN Header
- **Break field**: 13 bits minimum  
- **Delimiter**: 1 bit  
- **SYNC field**: 10 bits (1 start, 8 sync bits, 1 stop)  
- **Identifier field**: 10 bits (1 start, 6 ID bits, 2 parity bits, 1 stop)  

### LIN Response
- Up to **8 data bytes**, each with 10 bits (1 start, 8 data, 1 stop)  
- **Checksum field**: 10 bits (1 start, 8 checksum, 1 stop)  

---

## 🧪 Testbench Features

- **Constrained Random Verification (CRV)** for generating varied test scenarios  
- **Functional Coverage** using `cocotb_coverage` to ensure thorough protocol testing  
- **Bus Monitors** to observe and validate transactions on the LIN bus  
- **Scoreboarding** to compare expected vs. actual DUT behavior  
- **Protocol checks** for frame format, parity, and checksum correctness  

---

## 📂 Repository Structure

