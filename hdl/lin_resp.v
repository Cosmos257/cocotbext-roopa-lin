`timescale 1ns / 1ps

module lin_resp(
    input  wire        sys_clk,          // system clock
    input  wire        rstn,             // active-low reset
    input  wire        lin_busy,         // commander busy
    input  wire        comm_tx_done,     // TX complete from commander
    input  wire [33:0] frame_header_out, // header from commander
    input  wire [63:0] data,             // input data to responder
    output reg  [89:0] response_out,     // response from responder
    output wire [7:0]  checksum,         // checksum/CRC out
    output reg         sdo_resp,         // serial data out from responder
    output reg         resp_tx_done,     // TX complete from responder
    output reg         resp_busy         // responder busy
);

    // FSM states
    localparam IDLE     = 3'd0;
    localparam START    = 3'd1;
    localparam DATA     = 3'd2;
    localparam STOP     = 3'd3;
    localparam CHK_START= 3'd4;
    localparam CHECKSUM = 3'd5;
    localparam CHK_STOP = 3'd6;

    reg [2:0] state;
    reg [63:0] data_reg;
    reg [7:0] checksum_reg;
    reg [3:0] bit_count;
    reg [3:0] byte_count;

    wire [7:0] sync_data;
    wire [7:0] crc_in;

    assign sync_data = frame_header_out[19:12]; // sync byte = 0x55
    assign crc_in = 8'hFF;

    // CRC instantiation
    crcd64_o8 CRCD64_O8 (
        .crc_in(crc_in),
        .data_in(data),
        .crc_out(checksum)
    );

    // FSM for responder
    always @(posedge sys_clk or negedge rstn) begin
        if (!rstn) begin
            response_out   <= 90'd0;
            sdo_resp       <= 1'b1;   // line idle high
            resp_busy      <= 1'b0;
            resp_tx_done   <= 1'b0;
            state          <= IDLE;
            data_reg       <= 64'd0;
            checksum_reg   <= 8'd0;
            bit_count      <= 4'd0;
            byte_count     <= 4'd0;
        end else begin
            case(state)
                IDLE: begin
                    response_out   <= 90'd0;
                    resp_tx_done   <= 1'b0;
                    resp_busy      <= 1'b0;
                    bit_count      <= 4'd0;
                    byte_count     <= 4'd0;
                    if (!lin_busy && comm_tx_done && sync_data == 8'h55) begin
                        data_reg     <= data;
                        checksum_reg <= checksum;
                        resp_busy    <= 1'b1;
                        sdo_resp     <= 1'b0; // start bit
                        state        <= START;
                    end
                end

                // start bit already set
                START: begin
                    response_out <= {response_out[88:0], sdo_resp};
                    sdo_resp     <= data_reg[0];   // first data bit
                    data_reg     <= {1'b0, data_reg[63:1]};
                    bit_count    <= 4'd1;
                    state        <= DATA;
                end

                DATA: begin
                    response_out <= {response_out[88:0], sdo_resp};
                    if (bit_count < 8) begin
                        sdo_resp  <= data_reg[0];
                        data_reg  <= {1'b0, data_reg[63:1]};
                        bit_count <= bit_count + 1;
                    end else begin
                        sdo_resp  <= 1'b1; // stop bit
                        bit_count <= 4'd0;
                        state     <= STOP;
                    end
                end

                STOP: begin
                    response_out <= {response_out[88:0], sdo_resp};
                    if (byte_count < 7) begin
                        byte_count <= byte_count + 1;
                        sdo_resp   <= 1'b0; // next start bit
                        state      <= START;
                    end else begin
                        sdo_resp   <= 1'b0; // checksum start
                        state      <= CHK_START;
                    end
                end

                CHK_START: begin
                    response_out <= {response_out[88:0], sdo_resp};
                    sdo_resp     <= checksum_reg[0];
                    checksum_reg <= {1'b0, checksum_reg[7:1]};
                    bit_count    <= 4'd1;
                    state        <= CHECKSUM;
                end

                CHECKSUM: begin
                    response_out <= {response_out[88:0], sdo_resp};
                    if (bit_count < 8) begin
                        sdo_resp     <= checksum_reg[0];
                        checksum_reg <= {1'b0, checksum_reg[7:1]};
                        bit_count    <= bit_count + 1;
                    end else begin
                        sdo_resp  <= 1'b1; // checksum stop bit
                        state     <= CHK_STOP;
                    end
                end

                CHK_STOP: begin
                    response_out <= {response_out[88:0], sdo_resp};
                    resp_tx_done <= 1'b1;
                    resp_busy    <= 1'b0;
                    state        <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule
