`timescale 1ns / 1ps

module lin_top_wrapper;

    // Clock and reset
    reg         sys_clk;
    reg         rstn;

    // Inputs to DUT
    reg  [5:0]  pid;
    reg  [63:0] data;

    // Outputs from DUT
    wire        sdo_comm;
    wire        sdo_resp;
    wire [33:0] frame_header_out;
    wire [89:0] response_out;
    wire        comm_tx_done;
    wire        resp_tx_done;

    // Instantiate DUT
    lin_top DUT (
        .sys_clk        (sys_clk),
        .rstn           (rstn),
        .pid            (pid),
        .data           (data),
        .sdo_comm       (sdo_comm),
        .sdo_resp       (sdo_resp),
        .frame_header_out(frame_header_out),
        .response_out   (response_out),
        .comm_tx_done   (comm_tx_done),
        .resp_tx_done   (resp_tx_done)
    );

    initial begin
        $dumpfile("waves.vcd");
        $dumpvars;
        sys_clk=0;
        forever begin
                #5 sys_clk=~sys_clk;
        end
    end
endmodule
