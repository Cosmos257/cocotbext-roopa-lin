`timescale 1ns / 1ps

module lin_top(
    input  wire        sys_clk,       // system clock
    input  wire        rstn,          // reset
    input  wire [5:0]  pid,           // id or address
    input  wire [63:0] data,          // input data to responder
    output wire        sdo_comm,      // serial data out from commander
    output wire        sdo_resp,      // serial data out from responder
    output wire [33:0] frame_header_out, // header from commander
    output wire [89:0] response_out,     // response from responder
    output wire        comm_tx_done,  // tx complete from commander
    output wire        resp_tx_done    // tx complete from responder
    );

    reg         inter_tx_delay;    // inter transmission delay
    reg [4:0]   delay_count;       // inter transmission delay count
    reg         start;             // start commander
    wire        resp_busy;         // responder busy
    wire        lin_busy;          // commander busy
    reg [7:0]   checksum;          // responder checksum
    wire [123:0] frame_out;        // total frame from commander and responder

    // LIN Commander instantiation
    lin_comm LIN_COMM(
        .sys_clk        (sys_clk       ),
        .rstn           (rstn          ),
        .start          (start         ),
        .pid            (pid           ),
        .inter_tx_delay (inter_tx_delay),
        .resp_busy      (resp_busy     ),
        .sdo_comm       (sdo_comm      ),
        .lin_busy       (lin_busy      ),
        .comm_tx_done   (comm_tx_done  ),
        .frame_header_out (frame_header_out)
    );

    // LIN Responder instantiation
    lin_resp LIN_RESP(
        .sys_clk          (sys_clk         ),
        .rstn             (rstn            ),
        .lin_busy         (lin_busy        ),
        .comm_tx_done     (comm_tx_done    ),
        .frame_header_out (frame_header_out),
        .data             (data            ),
        .response_out     (response_out    ),
        .checksum         (checksum        ),
        .sdo_resp         (sdo_resp        ),
        .resp_tx_done     (resp_tx_done    ),
        .resp_busy        (resp_busy       )
    );

    // FSM states as localparams
    localparam IDLE  = 0;
    localparam DELAY = 1;
    reg state;

    assign frame_out = resp_tx_done ? {frame_header_out, response_out} : 0; // frame output after responder tx done

    // start condition for commander
    always @(posedge sys_clk or negedge rstn) begin
        if (!rstn) begin
            start <= 0;
        end else if (!resp_tx_done && !resp_busy) begin
            start <= 1;
        end else begin
            start <= 0;
        end
    end

    // delay generation after responder tx done
    always @(posedge sys_clk or negedge rstn) begin
        if (!rstn) begin
            inter_tx_delay <= 0;
            delay_count <= 0;
            state <= IDLE;
        end else begin
            case(state)
                IDLE: begin
                    inter_tx_delay <= 0;
                    delay_count <= 0;
                    if (resp_tx_done)
                        state <= DELAY;
                    else
                        state <= IDLE;
                end
                DELAY: begin
                    if (delay_count < 20) begin
                        delay_count <= delay_count + 1;
                        inter_tx_delay <= 1; // tx delay for 20 ns
                        state <= DELAY;
                    end else begin
                        delay_count <= 0;
                        inter_tx_delay <= 0;
                        state <= IDLE;
                    end
                end
                default: state <= IDLE;
            endcase
        end
    end

endmodule
