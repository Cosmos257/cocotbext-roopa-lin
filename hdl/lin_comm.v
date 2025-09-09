`timescale 1ns / 1ps

module lin_comm(
    input  wire        sys_clk,        // system clock
    input  wire        rstn,           // reset (active low)
    input  wire        start,          // start commander
    input  wire [5:0]  pid,            // id or address
    input  wire        inter_tx_delay, // inter transmission delay
    input  wire        resp_busy,      // responder busy
    output reg         sdo_comm,       // serial data out
    output wire        lin_busy,       // commander busy
    output reg         comm_tx_done,   // tx complete from commander
    output reg [33:0]  frame_header_out // frame header
    );

    // counters / registers
    reg [3:0] break_count;     // count for break field (needs to count >=13)
    reg [3:0] sync_count;      // count for sync field (0..9)
    reg [5:0] pid_adrs_reg;    // PID register (shifted out LSB first)
    reg [3:0] pid_count;       // count for PID (start + 6 id bits)
    reg [1:0] parity_count;    // count for parity (0..2)
    reg parity0;               // parity bit 0
    reg parity1;               // parity bit 1
    reg [33:0] frame_header;   // frame header register (34 bits)

    // temporary / helper
    reg next_sdo;              // the bit we intend to drive this cycle
    reg append_bit;            // whether to capture next_sdo into frame_header this cycle

    // SYNC pattern (LSB first sequence for 0x55 -> bits transmitted: 1,0,1,0,1,0,1,0 )
    localparam [7:0] SYNC_PATTERN = 8'b01010101; // bit0 = first transmitted data bit (LSB-first)

    // FSM states as localparams
    localparam IDLE       = 3'd0;
    localparam SYNC_BREAK = 3'd1;
    localparam SYNC_FIELD = 3'd2;
    localparam PID_STATE  = 3'd3;
    localparam PARITY     = 3'd4;
    localparam WAIT       = 3'd6;

    reg [2:0] state; // current state

    // Main synchronous FSM
    // Approach: compute next_sdo and append_bit (blocking style within this clock),
    // then update sdo_comm and frame_header using next_sdo so the captured header aligns
    // exactly with the bits driven on sdo_comm (no one-cycle offset).
    always @(posedge sys_clk or negedge rstn) begin
        if (!rstn) begin
            // reset all sequential state
            sdo_comm       <= 1'b0;
            break_count    <= 4'd0;
            sync_count     <= 4'd0;
            pid_count      <= 4'd0;
            pid_adrs_reg   <= 6'd0;
            parity_count   <= 2'd0;
            parity0        <= 1'b0;
            parity1        <= 1'b0;
            comm_tx_done   <= 1'b0;
            frame_header   <= 34'd0;
            state          <= IDLE;
            next_sdo       <= 1'b0;
            append_bit     <= 1'b0;
        end else begin
            // Default behaviors for the combinational decisions in this clock
            // Use blocking assignments for next_sdo/append_bit so these are used
            // when updating frame_header and sdo_comm below.
            next_sdo   = 1'b1;   // idle-high by default (can be overridden)
            append_bit = 1'b0;   // do not append unless explicitly requested

            // Default: keep most sequential regs the same unless updated using non-blocking below
            case (state)
                IDLE: begin
                    // In IDLE we latch PID and wait for start condition
                    // Keep outputs/reset counters as needed
                    // Drive bus idle value (choose 1 or 0 depending on bus convention)
                    next_sdo = 1'b1; // idle-high
                    append_bit = 1'b0;

                    // make sure comm_tx_done is cleared when entering IDLE
                    comm_tx_done <= 1'b0;
                    break_count  <= 4'd0;
                    sync_count   <= 4'd0;
                    pid_count    <= 4'd0;
                    parity_count <= 2'd0;
                    pid_adrs_reg <= pid; // latch PID value

                    if (start && !inter_tx_delay && !resp_busy) begin
                        state <= SYNC_BREAK;
                    end else begin
                        state <= IDLE;
                    end
                end

                // SYNC_BREAK: drive >=13 low bits, then one delimiter high
                SYNC_BREAK: begin
                    if (break_count < 13) begin
                        next_sdo = 1'b0;    // drive break low
                        append_bit = 1'b1;  // capture this bit into header
                        break_count <= break_count + 1;
                        state <= SYNC_BREAK;
                    end else begin
                        next_sdo = 1'b1;    // delimiter high
                        append_bit = 1'b1;
                        break_count <= 4'd0;
                        state <= SYNC_FIELD;
                    end
                end

                // SYNC_FIELD: start(0), 8-data bits (0x55 LSB-first), stop(1)
                SYNC_FIELD: begin
                    if (sync_count == 0) begin
                        next_sdo = 1'b0;    // start bit
                        append_bit = 1'b1;
                        sync_count <= sync_count + 1;
                        state <= SYNC_FIELD;
                    end else if (sync_count >= 1 && sync_count <= 8) begin
                        next_sdo = SYNC_PATTERN[sync_count-1]; // data bits LSB-first
                        append_bit = 1'b1;
                        sync_count <= sync_count + 1;
                        state <= SYNC_FIELD;
                    end else begin
                        // sync_count == 9 -> stop bit
                        next_sdo = 1'b1;    // stop bit
                        append_bit = 1'b1;
                        sync_count <= 4'd0;
                        state <= PID_STATE;
                    end
                end

                // PID_STATE: start(0) + 6 ID bits (LSB-first)
                PID_STATE: begin
                    if (pid_count == 0) begin
                        next_sdo = 1'b0;    // PID start bit
                        append_bit = 1'b1;
                        pid_count <= pid_count + 1;
                        state <= PID_STATE;
                    end else if (pid_count >= 1 && pid_count <= 6) begin
                        // send LSB-first ID bits and shift the register
                        next_sdo = pid_adrs_reg[0];
                        append_bit = 1'b1;
                        pid_adrs_reg <= {1'b0, pid_adrs_reg[5:1]};
                        pid_count <= pid_count + 1;
                        state <= PID_STATE;
                    end else begin
                        // finished sending ID bits -> compute parity and go to PARITY
                        parity0 <= pid[0] ^ pid[1] ^ pid[2] ^ pid[4];
                        parity1 <= ~(pid[1] ^ pid[3] ^ pid[4] ^ pid[5]);
                        pid_count <= 4'd0;
                        parity_count <= 2'd0;
                        // do NOT append here; parity state will drive the parity bits
                        state <= PARITY;
                    end
                end

                // PARITY: send P0, P1, then a stop bit and finish (move to WAIT)
                PARITY: begin
                    if (parity_count == 0) begin
                        next_sdo = parity0;
                        append_bit = 1'b1;
                        parity_count <= parity_count + 1;
                        state <= PARITY;
                    end else if (parity_count == 1) begin
                        next_sdo = parity1;
                        append_bit = 1'b1;
                        parity_count <= parity_count + 1;
                        state <= PARITY;
                    end else begin
                        // After two parity bits, drive the PID stop bit (1), append it,
                        // assert comm_tx_done and move to WAIT in the same cycle so
                        // the frame_header contains exactly the complete header.
                        next_sdo = 1'b1;    // PID stop bit
                        append_bit = 1'b1;
                        parity_count <= 2'd0;
                        comm_tx_done <= 1'b1; // indicate header is complete (available)
                        state <= WAIT;
                    end
                end

                // WAIT: wait for responder to become not busy, then go to IDLE
                WAIT: begin
                    next_sdo = 1'b1; // idle level
                    append_bit = 1'b0;
                    if (resp_busy)
                        state <= WAIT;
                    else
                        state <= IDLE;
                end

                default: begin
                    next_sdo = 1'b1;
                    append_bit = 1'b0;
                    state <= IDLE;
                end
            endcase

            // Update the driven line and optionally capture it into the header
            // Use non-blocking updates so sequential behavior is correct.
            sdo_comm <= next_sdo;
            if (append_bit)
                frame_header <= {frame_header[32:0], next_sdo};
            else
                frame_header <= frame_header;
        end
    end

    assign lin_busy = (state == SYNC_BREAK) || (state == SYNC_FIELD) || (state == PID_STATE) || (state == PARITY);

    // Provide the captured header externally only when comm_tx_done is asserted.
    always @(*) frame_header_out = comm_tx_done ? frame_header : 34'd0;

endmodule
